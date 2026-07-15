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
/// passwords fail cleanly via the GCM authentication tag (there is no separate
/// password check — authentication *is* the check).
public enum EnvCrypto {
    public static let currentVersion = 1

    /// Encode `export` as JSON, derive a key from `password`, and seal it into a
    /// `.envenc` envelope (pretty-printed, sorted keys, so envelopes diff cleanly).
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

    /// Open a `.envenc` envelope. Distinguishes "not an envelope at all"
    /// (`.malformedEnvelope`) from "envelope is fine but the key is wrong or the
    /// ciphertext was modified" (`.wrongPasswordOrCorrupted`).
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
