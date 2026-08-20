// Round-trip tests for SSH client public-key authentication: build a real
// private key, parse it with `SSHPrivateKey`, produce a userauth signature
// blob, and verify it with the already-tested `SSHCrypto.verifyHostKey` (which
// parses the same public-key/signature wire formats). If parsing, signing, or
// the blob encoding is wrong for any key type, verification fails here.

import XCTest
import CryptoKit
#if canImport(Security)
import Security
#endif
@testable import NetToolboxKit

final class SSHKeyTests: XCTestCase {
    private let message = Data("nettoolbox-ssh-auth-test".utf8)

    func testEd25519OpenSSHRoundTrip() throws {
        let priv = Curve25519.Signing.PrivateKey()
        let pub = priv.publicKey.rawRepresentation

        var pubBlob = Data()
        SSHWire.putString("ssh-ed25519", into: &pubBlob)
        SSHWire.putString(pub, into: &pubBlob)

        var fields = Data()
        SSHWire.putString("ssh-ed25519", into: &fields)
        SSHWire.putString(pub, into: &fields)
        SSHWire.putString(priv.rawRepresentation + pub, into: &fields)   // seed(32) || pub(32)

        let key = try SSHPrivateKey(parsing: Self.opensshPEM(publicBlob: pubBlob, privateFields: fields))
        XCTAssertEqual(key.authAlgorithm, "ssh-ed25519")
        let signature = try key.signatureBlob(over: message)
        XCTAssertTrue(SSHCrypto.verifyHostKey(blob: key.publicKeyBlob, signature: signature, over: message))
    }

    func testECDSAP256OpenSSHRoundTrip() throws {
        let priv = P256.Signing.PrivateKey()
        let q = priv.publicKey.x963Representation   // 0x04 || X || Y
        let d = priv.rawRepresentation

        var pubBlob = Data()
        SSHWire.putString("ecdsa-sha2-nistp256", into: &pubBlob)
        SSHWire.putString("nistp256", into: &pubBlob)
        SSHWire.putString(q, into: &pubBlob)

        var fields = Data()
        SSHWire.putString("ecdsa-sha2-nistp256", into: &fields)
        SSHWire.putString("nistp256", into: &fields)
        SSHWire.putString(q, into: &fields)
        SSHWire.putMPInt(d, into: &fields)

        let key = try SSHPrivateKey(parsing: Self.opensshPEM(publicBlob: pubBlob, privateFields: fields))
        XCTAssertEqual(key.authAlgorithm, "ecdsa-sha2-nistp256")
        let signature = try key.signatureBlob(over: message)
        XCTAssertTrue(SSHCrypto.verifyHostKey(blob: key.publicKeyBlob, signature: signature, over: message))
    }

    #if canImport(Security)
    func testRSAPEMRoundTrip() throws {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048,
        ]
        guard let priv = SecKeyCreateRandomKey(attributes as CFDictionary, nil),
              let der = SecKeyCopyExternalRepresentation(priv, nil) as Data? else {
            return XCTFail("could not generate an RSA key")
        }
        let pem = "-----BEGIN RSA PRIVATE KEY-----\n"
            + der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            + "\n-----END RSA PRIVATE KEY-----"

        let key = try SSHPrivateKey(parsing: pem)
        XCTAssertEqual(key.authAlgorithm, "rsa-sha2-512")
        let signature = try key.signatureBlob(over: message)
        XCTAssertTrue(SSHCrypto.verifyHostKey(blob: key.publicKeyBlob, signature: signature, over: message))
    }
    #endif

    func testEncryptedOpenSSHKeyRejected() {
        var body = Data("openssh-key-v1\u{0}".utf8)
        SSHWire.putString("aes256-ctr", into: &body)   // not "none" → encrypted
        let pem = "-----BEGIN OPENSSH PRIVATE KEY-----\n"
            + body.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            + "\n-----END OPENSSH PRIVATE KEY-----"
        XCTAssertThrowsError(try SSHPrivateKey(parsing: pem)) { error in
            XCTAssertEqual(error as? SSHKeyError, .encrypted)
        }
    }

    func testUnsupportedFormatRejected() {
        XCTAssertThrowsError(try SSHPrivateKey(parsing: "-----BEGIN PGP MESSAGE-----")) { error in
            XCTAssertEqual(error as? SSHKeyError, .unsupportedFormat)
        }
    }

    // Assembles an unencrypted openssh-key-v1 container around the given public
    // blob and private-key fields.
    private static func opensshPEM(publicBlob: Data, privateFields: Data) -> String {
        var body = Data("openssh-key-v1\u{0}".utf8)
        SSHWire.putString("none", into: &body)     // ciphername
        SSHWire.putString("none", into: &body)     // kdfname
        SSHWire.putString(Data(), into: &body)     // kdfoptions
        SSHWire.putUInt32(1, into: &body)          // number of keys
        SSHWire.putString(publicBlob, into: &body)

        var section = Data()
        SSHWire.putUInt32(0x0102_0304, into: &section)   // checkint1
        SSHWire.putUInt32(0x0102_0304, into: &section)   // checkint2 (must match)
        section.append(privateFields)
        SSHWire.putString("test@nettoolbox", into: &section)   // comment
        var pad: UInt8 = 1
        while section.count % 8 != 0 { section.append(pad); pad += 1 }
        SSHWire.putString(section, into: &body)

        let base64 = body.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN OPENSSH PRIVATE KEY-----\n" + base64 + "\n-----END OPENSSH PRIVATE KEY-----"
    }
}
