import Foundation
import CryptoKit
#if canImport(Security)
import Security
#endif

/// Why a pasted private key could not be used, with a message that tells the
/// user how to fix it.
enum SSHKeyError: LocalizedError, Equatable {
    case unsupportedFormat
    case encrypted
    case opensshRSANeedsPEM
    case parseFailed
    case signingUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: L10nString("ssh.key.error.format")
        case .encrypted: L10nString("ssh.key.error.encrypted")
        case .opensshRSANeedsPEM: L10nString("ssh.key.error.rsaPem")
        case .parseFailed: L10nString("ssh.key.error.parse")
        case .signingUnavailable: L10nString("ssh.key.error.signing")
        }
    }
}

/// A parsed SSH private key used for public-key authentication. Supports, with
/// no third-party code (CryptoKit for Curve25519/NIST curves, Security for
/// RSA):
///   * OpenSSH format ("BEGIN OPENSSH PRIVATE KEY"), unencrypted:
///     ed25519 and ecdsa-nistp256/384/521.
///   * PEM PKCS#1 ("BEGIN RSA PRIVATE KEY"): RSA (signed rsa-sha2-512).
///
/// Passphrase-protected keys, PKCS#8, SEC1 EC-PEM and OpenSSH-format RSA are
/// rejected with a specific, actionable error (the last suggests converting to
/// PEM with `ssh-keygen -p -m PEM`).
struct SSHPrivateKey: Sendable {
    enum Signer: Sendable {
        case ed25519(Curve25519.Signing.PrivateKey)
        case p256(P256.Signing.PrivateKey)
        case p384(P384.Signing.PrivateKey)
        case p521(P521.Signing.PrivateKey)
        case rsa(der: Data)   // PKCS#1 RSAPrivateKey DER
    }

    private let signer: Signer

    /// The "public key algorithm name" carried in the userauth request; it must
    /// equal the signature type. ssh-ed25519 / ecdsa-sha2-nistp{256,384,521} /
    /// rsa-sha2-512.
    let authAlgorithm: String

    /// The public-key blob: string(type) || … — exactly what a userauth
    /// "publickey" request carries.
    let publicKeyBlob: Data

    /// Back-compatible optional parse (nil on any failure).
    init?(pem: String) {
        guard let parsed = try? SSHPrivateKey(parsing: pem) else { return nil }
        self = parsed
    }

    /// Throwing parse that explains *why* a key was rejected.
    init(parsing pem: String) throws {
        let text = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.contains("BEGIN OPENSSH PRIVATE KEY") {
            try self.init(openssh: text)
        } else if text.contains("BEGIN RSA PRIVATE KEY") {
            try self.init(pkcs1RSA: text)
        } else {
            // PKCS#8 ("BEGIN PRIVATE KEY"), SEC1 EC ("BEGIN EC PRIVATE KEY"),
            // encrypted PEM, or anything else — not supported yet.
            throw SSHKeyError.unsupportedFormat
        }
    }

    // MARK: - OpenSSH format

    private init(openssh pem: String) throws {
        let base64 = pem.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("-----") }.joined()
        guard let raw = Data(base64Encoded: base64) else { throw SSHKeyError.parseFailed }
        let magic = Array("openssh-key-v1\u{0}".utf8)
        guard raw.starts(with: magic) else { throw SSHKeyError.parseFailed }

        var reader = SSHWire.Reader(Data(raw.dropFirst(magic.count)))
        guard let cipher = reader.readStringUTF8() else { throw SSHKeyError.parseFailed }
        guard cipher == "none" else { throw SSHKeyError.encrypted }
        guard reader.readStringUTF8() != nil,        // kdfname
              reader.readString() != nil,            // kdfoptions
              let keyCount = reader.readUInt32(), keyCount == 1,
              let pubBlob = reader.readString(),
              let privateSection = reader.readString() else { throw SSHKeyError.parseFailed }

        var priv = SSHWire.Reader(privateSection)
        guard priv.readUInt32() != nil,              // checkint1
              priv.readUInt32() != nil,              // checkint2
              let keyType = priv.readStringUTF8() else { throw SSHKeyError.parseFailed }

        switch keyType {
        case "ssh-ed25519":
            guard priv.readString() != nil,                             // public key (32)
                  let secret = priv.readString(), secret.count >= 32,   // seed(32) || pub(32)
                  let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: secret.prefix(32)) else {
                throw SSHKeyError.parseFailed
            }
            self.signer = .ed25519(key)
            self.authAlgorithm = "ssh-ed25519"

        case "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521":
            guard priv.readString() != nil,          // curve name
                  priv.readString() != nil,          // Q (public point)
                  let d = priv.readString() else { throw SSHKeyError.parseFailed }
            switch keyType {
            case "ecdsa-sha2-nistp256":
                guard let k = try? P256.Signing.PrivateKey(rawRepresentation: Self.leftPad(d, to: 32)) else { throw SSHKeyError.parseFailed }
                self.signer = .p256(k)
            case "ecdsa-sha2-nistp384":
                guard let k = try? P384.Signing.PrivateKey(rawRepresentation: Self.leftPad(d, to: 48)) else { throw SSHKeyError.parseFailed }
                self.signer = .p384(k)
            default:
                guard let k = try? P521.Signing.PrivateKey(rawRepresentation: Self.leftPad(d, to: 66)) else { throw SSHKeyError.parseFailed }
                self.signer = .p521(k)
            }
            self.authAlgorithm = keyType

        case "ssh-rsa":
            // OpenSSH-format RSA omits the CRT parameters (dP/dQ) that a SecKey
            // needs, and we don't ship a bignum to derive them — ask the user to
            // export the key as PEM instead.
            throw SSHKeyError.opensshRSANeedsPEM

        default:
            throw SSHKeyError.unsupportedFormat
        }
        self.publicKeyBlob = pubBlob
    }

    // MARK: - PEM PKCS#1 RSA

    private init(pkcs1RSA pem: String) throws {
        #if canImport(Security)
        let base64 = pem.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("-----") }.joined()
        guard let der = Data(base64Encoded: base64) else { throw SSHKeyError.parseFailed }
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
        ]
        guard let secKey = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil),
              let publicKey = SecKeyCopyPublicKey(secKey),
              let publicDER = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let integers = SSHDER.sequenceIntegers(publicDER), integers.count == 2 else {
            throw SSHKeyError.parseFailed
        }
        // SecKey's RSA public representation is RSAPublicKey ::= SEQUENCE { n, e }.
        let n = integers[0], e = integers[1]
        var blob = Data()
        SSHWire.putString("ssh-rsa", into: &blob)
        SSHWire.putMPInt(e, into: &blob)
        SSHWire.putMPInt(n, into: &blob)

        self.signer = .rsa(der: der)
        self.authAlgorithm = "rsa-sha2-512"
        self.publicKeyBlob = blob
        #else
        throw SSHKeyError.signingUnavailable
        #endif
    }

    // MARK: - Signing

    /// Produces the full SSH signature blob — string(algorithm) ||
    /// string(signature) — over `data` (which the caller forms as
    /// string(session_id) || userauth-request).
    func signatureBlob(over data: Data) throws -> Data {
        switch signer {
        case .ed25519(let key):
            return Self.wrap("ssh-ed25519", try key.signature(for: data))
        case .p256(let key):
            return Self.wrap("ecdsa-sha2-nistp256", Self.ecdsaSSHSignature(try key.signature(for: data).rawRepresentation, half: 32))
        case .p384(let key):
            return Self.wrap("ecdsa-sha2-nistp384", Self.ecdsaSSHSignature(try key.signature(for: data).rawRepresentation, half: 48))
        case .p521(let key):
            return Self.wrap("ecdsa-sha2-nistp521", Self.ecdsaSSHSignature(try key.signature(for: data).rawRepresentation, half: 66))
        case .rsa(let der):
            return Self.wrap("rsa-sha2-512", try Self.rsaSign(der: der, data: data))
        }
    }

    /// Ed25519 raw signature over `data` (kept for the on-device self-tests).
    func sign(_ data: Data) throws -> Data {
        guard case .ed25519(let key) = signer else { throw SSHKeyError.signingUnavailable }
        return try key.signature(for: data)
    }

    private static func wrap(_ name: String, _ signature: Data) -> Data {
        var out = Data()
        SSHWire.putString(name, into: &out)
        SSHWire.putString(signature, into: &out)
        return out
    }

    /// Converts CryptoKit's fixed-width r‖s into SSH's
    /// string(mpint r) || string(mpint s).
    private static func ecdsaSSHSignature(_ raw: Data, half: Int) -> Data {
        let bytes = Array(raw)
        let r = Data(bytes.prefix(half))
        let s = Data(bytes.suffix(max(0, bytes.count - half)))
        var out = Data()
        SSHWire.putMPInt(r, into: &out)
        SSHWire.putMPInt(s, into: &out)
        return out
    }

    private static func rsaSign(der: Data, data: Data) throws -> Data {
        #if canImport(Security)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
        ]
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil) else {
            throw SSHKeyError.parseFailed
        }
        guard let signature = SecKeyCreateSignature(
            key, .rsaSignatureMessagePKCS1v15SHA512, data as CFData, nil
        ) as Data? else {
            throw SSHKeyError.signingUnavailable
        }
        return signature
        #else
        throw SSHKeyError.signingUnavailable
        #endif
    }

    /// Strips leading zeros then left-pads a scalar to exactly `size` bytes,
    /// which is what CryptoKit's `rawRepresentation` initialisers expect.
    private static func leftPad(_ data: Data, to size: Int) -> Data {
        var bytes = Array(data)
        while bytes.first == 0 { bytes.removeFirst() }
        if bytes.count > size { bytes = Array(bytes.suffix(size)) }
        return Data(repeating: 0, count: max(0, size - bytes.count)) + Data(bytes)
    }
}

/// The tiny slice of DER parsing the RSA path needs: pull the INTEGERs out of a
/// `SEQUENCE { INTEGER, INTEGER, … }` (an RSA public key). Returns each
/// integer's content bytes verbatim (leading 0x00 kept; `putMPInt` strips it).
enum SSHDER {
    static func sequenceIntegers(_ data: Data) -> [Data]? {
        var reader = Reader(data)
        guard reader.readByte() == 0x30, reader.readLength() != nil else { return nil }
        var integers: [Data] = []
        while !reader.isAtEnd {
            guard reader.readByte() == 0x02, let length = reader.readLength(),
                  let value = reader.read(length) else { return nil }
            integers.append(value)
        }
        return integers
    }

    private struct Reader {
        private let data: [UInt8]
        private var index = 0
        init(_ data: Data) { self.data = Array(data) }
        var isAtEnd: Bool { index >= data.count }

        mutating func readByte() -> UInt8? {
            guard index < data.count else { return nil }
            defer { index += 1 }
            return data[index]
        }

        /// DER definite length: short form (< 0x80) or long form (low 7 bits =
        /// number of subsequent big-endian length bytes).
        mutating func readLength() -> Int? {
            guard let first = readByte() else { return nil }
            if first < 0x80 { return Int(first) }
            let count = Int(first & 0x7F)
            guard count > 0, count <= 8 else { return nil }
            var value = 0
            for _ in 0..<count {
                guard let byte = readByte() else { return nil }
                value = (value << 8) | Int(byte)
            }
            return value
        }

        mutating func read(_ count: Int) -> Data? {
            guard count >= 0, index + count <= data.count else { return nil }
            defer { index += count }
            return Data(data[index..<index + count])
        }
    }
}
