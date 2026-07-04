import Foundation
import CryptoKit
import Model

// `EnvelopeError` is defined in the `Model` module so it's visible to the app.

/// The on-disk `.envenc` JSON envelope.
struct Envelope: Codable {
    var version: Int
    var type: String
    var kdf: String
    var kdfParams: ScryptParams
    var salt: String        // base64
    var nonce: String       // base64
    var ciphertext: String  // base64 of (ciphertext || 16-byte GCM tag)
}

/// AES-256-GCM encryption of an `EnvExport`, with an scrypt-derived key. Wrong
/// passwords fail cleanly via the GCM authentication tag.
public enum EnvCrypto {
    public static let currentVersion = 1

    public static func encrypt(_ export: EnvExport, password: String, params: ScryptParams = .default) throws -> Data {
        let plaintext = try JSONEncoder().encode(export)

        // 16-byte random salt (CryptoKit CSPRNG).
        let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Array($0) }
        let keyBytes = try Scrypt.derive(
            password: Array(password.utf8), salt: salt,
            N: params.N, r: params.r, p: params.p, dkLen: 32
        )
        let key = SymmetricKey(data: keyBytes)

        let sealed = try AES.GCM.seal(plaintext, using: key)
        let nonceData = Data(sealed.nonce)
        let ctTag = sealed.ciphertext + sealed.tag

        let envelope = Envelope(
            version: currentVersion,
            type: export.type.rawValue,
            kdf: "scrypt",
            kdfParams: params,
            salt: Data(salt).base64EncodedString(),
            nonce: nonceData.base64EncodedString(),
            ciphertext: ctTag.base64EncodedString()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    public static func decrypt(_ data: Data, password: String) throws -> EnvExport {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw EnvelopeError.malformedEnvelope
        }
        guard envelope.version == currentVersion else { throw EnvelopeError.unsupportedVersion(envelope.version) }
        guard envelope.kdf == "scrypt" else { throw EnvelopeError.unsupportedKDF(envelope.kdf) }
        guard let salt = Data(base64Encoded: envelope.salt),
              let nonceData = Data(base64Encoded: envelope.nonce),
              let ctTag = Data(base64Encoded: envelope.ciphertext),
              ctTag.count >= 16
        else { throw EnvelopeError.malformedEnvelope }

        let keyBytes = try Scrypt.derive(
            password: Array(password.utf8), salt: Array(salt),
            N: envelope.kdfParams.N, r: envelope.kdfParams.r, p: envelope.kdfParams.p, dkLen: 32
        )
        let key = SymmetricKey(data: keyBytes)

        let tag = ctTag.suffix(16)
        let ciphertext = ctTag.prefix(ctTag.count - 16)
        let plaintext: Data
        do {
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            plaintext = try AES.GCM.open(box, using: key)
        } catch {
            throw EnvelopeError.wrongPasswordOrCorrupted
        }

        do {
            return try JSONDecoder().decode(EnvExport.self, from: plaintext)
        } catch {
            throw EnvelopeError.malformedEnvelope
        }
    }
}

/// scrypt (RFC 7914) built on CryptoKit's HMAC-SHA256 (for PBKDF2) — no third-party
/// crypto and no CommonCrypto. Validated against the RFC 7914 test vectors.
enum Scrypt {
    static func derive(password: [UInt8], salt: [UInt8], N: Int, r: Int, p: Int, dkLen: Int) throws -> [UInt8] {
        guard N > 1, (N & (N - 1)) == 0, r > 0, p > 0 else { throw EnvelopeError.invalidScryptParams }
        let blockBytes = 128 * r
        var b = pbkdf2SHA256(password: password, salt: salt, rounds: 1, dkLen: p * blockBytes)

        for i in 0..<p {
            let start = i * blockBytes
            var words = bytesToWords(Array(b[start..<start + blockBytes]))
            roMix(&words, N: N, r: r)
            b.replaceSubrange(start..<start + blockBytes, with: wordsToBytes(words))
        }
        return pbkdf2SHA256(password: password, salt: b, rounds: 1, dkLen: dkLen)
    }

    // MARK: PBKDF2-HMAC-SHA256

    static func pbkdf2SHA256(password: [UInt8], salt: [UInt8], rounds: Int, dkLen: Int) -> [UInt8] {
        let key = SymmetricKey(data: password)
        let hLen = 32
        let blocks = (dkLen + hLen - 1) / hLen
        var output = [UInt8]()
        output.reserveCapacity(blocks * hLen)

        for i in 1...max(blocks, 1) {
            var message = salt
            message.append(UInt8((i >> 24) & 0xff))
            message.append(UInt8((i >> 16) & 0xff))
            message.append(UInt8((i >> 8) & 0xff))
            message.append(UInt8(i & 0xff))
            var u = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
            var t = u
            if rounds > 1 {
                for _ in 2...rounds {
                    u = Array(HMAC<SHA256>.authenticationCode(for: u, using: key))
                    for k in 0..<hLen { t[k] ^= u[k] }
                }
            }
            output.append(contentsOf: t)
        }
        return Array(output.prefix(dkLen))
    }

    // MARK: Salsa20/8 + BlockMix + ROMix (operating on little-endian 32-bit words)

    private static func salsa20_8(_ input: [UInt32]) -> [UInt32] {
        func rotl(_ a: UInt32, _ b: UInt32) -> UInt32 { (a << b) | (a >> (32 - b)) }
        var x = input
        for _ in 0..<4 {
            x[4] ^= rotl(x[0] &+ x[12], 7);   x[8] ^= rotl(x[4] &+ x[0], 9)
            x[12] ^= rotl(x[8] &+ x[4], 13);  x[0] ^= rotl(x[12] &+ x[8], 18)
            x[9] ^= rotl(x[5] &+ x[1], 7);    x[13] ^= rotl(x[9] &+ x[5], 9)
            x[1] ^= rotl(x[13] &+ x[9], 13);  x[5] ^= rotl(x[1] &+ x[13], 18)
            x[14] ^= rotl(x[10] &+ x[6], 7);  x[2] ^= rotl(x[14] &+ x[10], 9)
            x[6] ^= rotl(x[2] &+ x[14], 13);  x[10] ^= rotl(x[6] &+ x[2], 18)
            x[3] ^= rotl(x[15] &+ x[11], 7);  x[7] ^= rotl(x[3] &+ x[15], 9)
            x[11] ^= rotl(x[7] &+ x[3], 13);  x[15] ^= rotl(x[11] &+ x[7], 18)
            x[1] ^= rotl(x[0] &+ x[3], 7);    x[2] ^= rotl(x[1] &+ x[0], 9)
            x[3] ^= rotl(x[2] &+ x[1], 13);   x[0] ^= rotl(x[3] &+ x[2], 18)
            x[6] ^= rotl(x[5] &+ x[4], 7);    x[7] ^= rotl(x[6] &+ x[5], 9)
            x[4] ^= rotl(x[7] &+ x[6], 13);   x[5] ^= rotl(x[4] &+ x[7], 18)
            x[11] ^= rotl(x[10] &+ x[9], 7);  x[8] ^= rotl(x[11] &+ x[10], 9)
            x[9] ^= rotl(x[8] &+ x[11], 13);  x[10] ^= rotl(x[9] &+ x[8], 18)
            x[12] ^= rotl(x[15] &+ x[14], 7); x[13] ^= rotl(x[12] &+ x[15], 9)
            x[14] ^= rotl(x[13] &+ x[12], 13);x[15] ^= rotl(x[14] &+ x[13], 18)
        }
        var out = [UInt32](repeating: 0, count: 16)
        for i in 0..<16 { out[i] = x[i] &+ input[i] }
        return out
    }

    private static func blockMix(_ b: [UInt32], r: Int) -> [UInt32] {
        var x = Array(b[(2 * r - 1) * 16 ..< 2 * r * 16])
        var y = [UInt32](repeating: 0, count: 32 * r)
        for i in 0..<(2 * r) {
            var t = [UInt32](repeating: 0, count: 16)
            for k in 0..<16 { t[k] = x[k] ^ b[i * 16 + k] }
            x = salsa20_8(t)
            let pos = (i % 2 == 0) ? (i / 2) : (r + (i - 1) / 2)
            for k in 0..<16 { y[pos * 16 + k] = x[k] }
        }
        return y
    }

    private static func roMix(_ b: inout [UInt32], N: Int, r: Int) {
        let words = 32 * r
        var x = b
        var v = [[UInt32]]()
        v.reserveCapacity(N)
        for _ in 0..<N {
            v.append(x)
            x = blockMix(x, r: r)
        }
        for _ in 0..<N {
            let j = Int(x[(2 * r - 1) * 16] % UInt32(N))
            var t = [UInt32](repeating: 0, count: words)
            for k in 0..<words { t[k] = x[k] ^ v[j][k] }
            x = blockMix(t, r: r)
        }
        b = x
    }

    // MARK: Byte/word conversion (little-endian)

    private static func bytesToWords(_ bytes: [UInt8]) -> [UInt32] {
        var w = [UInt32](repeating: 0, count: bytes.count / 4)
        for i in 0..<w.count {
            w[i] = UInt32(bytes[4 * i])
                | (UInt32(bytes[4 * i + 1]) << 8)
                | (UInt32(bytes[4 * i + 2]) << 16)
                | (UInt32(bytes[4 * i + 3]) << 24)
        }
        return w
    }

    private static func wordsToBytes(_ words: [UInt32]) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: words.count * 4)
        for i in 0..<words.count {
            b[4 * i] = UInt8(words[i] & 0xff)
            b[4 * i + 1] = UInt8((words[i] >> 8) & 0xff)
            b[4 * i + 2] = UInt8((words[i] >> 16) & 0xff)
            b[4 * i + 3] = UInt8((words[i] >> 24) & 0xff)
        }
        return b
    }
}
