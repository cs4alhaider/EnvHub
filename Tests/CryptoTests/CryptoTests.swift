import Testing
import Foundation
@testable import Crypto
import Model

@Suite("Crypto")
struct CryptoTests {
    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: scrypt against the official RFC 7914 test vectors

    @Test("scrypt matches RFC 7914 vector (password / NaCl, N=1024 r=8 p=16)")
    func rfcVector2() throws {
        let dk = try Scrypt.derive(
            password: Array("password".utf8), salt: Array("NaCl".utf8),
            N: 1024, r: 8, p: 16, dkLen: 64
        )
        #expect(hex(dk) == "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640")
    }

    @Test("scrypt matches RFC 7914 vector (pleaseletmein / SodiumChloride, N=16384 r=8 p=1)")
    func rfcVector3() throws {
        let dk = try Scrypt.derive(
            password: Array("pleaseletmein".utf8), salt: Array("SodiumChloride".utf8),
            N: 16384, r: 8, p: 1, dkLen: 64
        )
        #expect(hex(dk) == "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887")
    }

    // MARK: Envelope round-trip / failure modes

    private var sampleExport: EnvExport {
        EnvExport(type: .single, name: ".env", files: [
            EnvFilePayload(
                name: ".env", kind: "development",
                variables: [EnvVarPayload(key: "API_KEY", value: "secret"), EnvVarPayload(key: "PORT", value: "3000")],
                content: "API_KEY=secret\nPORT=3000\n"
            )
        ])
    }
    // Fast params so the crypto tests stay quick.
    private let fast = ScryptParams(N: 1024, r: 8, p: 1)

    @Test("Round-trips an export through encrypt/decrypt")
    func roundTrip() throws {
        let data = try EnvCrypto.encrypt(sampleExport, password: "hunter2", params: fast)
        let out = try EnvCrypto.decrypt(data, password: "hunter2")
        #expect(out == sampleExport)
    }

    @Test("Envelope carries the documented fields")
    func envelopeFields() throws {
        let data = try EnvCrypto.encrypt(sampleExport, password: "pw", params: fast)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["version"] as? Int == 1)
        #expect(json?["kdf"] as? String == "scrypt")
        #expect(json?["type"] as? String == "single")
        #expect((json?["kdfParams"] as? [String: Any])?["N"] as? Int == 1024)
        #expect(json?["salt"] is String)
        #expect(json?["nonce"] is String)
        #expect(json?["ciphertext"] is String)
    }

    @Test("Wrong password fails cleanly via the GCM tag")
    func wrongPassword() throws {
        let data = try EnvCrypto.encrypt(sampleExport, password: "correct", params: fast)
        #expect(throws: EnvelopeError.wrongPasswordOrCorrupted) {
            try EnvCrypto.decrypt(data, password: "incorrect")
        }
    }

    @Test("Tampered ciphertext fails authentication")
    func tamper() throws {
        let data = try EnvCrypto.encrypt(sampleExport, password: "pw", params: fast)
        var envelope = try JSONDecoder().decode(Envelope.self, from: data)
        var ct = Data(base64Encoded: envelope.ciphertext)!
        ct[0] ^= 0xFF
        envelope.ciphertext = ct.base64EncodedString()
        let tampered = try JSONEncoder().encode(envelope)
        #expect(throws: EnvelopeError.wrongPasswordOrCorrupted) {
            try EnvCrypto.decrypt(tampered, password: "pw")
        }
    }
}
