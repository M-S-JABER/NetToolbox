import Foundation
import CryptoKit
#if canImport(Security)
import Security
#endif

/// The crypto used by the SSH transport, built entirely on CryptoKit and
/// Security — no third-party code, so it stays inside the Playgrounds
/// zero-dependency rule. Key exchange is `curve25519-sha256`, the cipher is
/// `aes256-gcm@openssh.com`, and host keys are verified for ed25519,
/// ecdsa-nistp256 and rsa-sha2-256/512.
enum SSHCrypto {
    /// SHA-256 exchange hash H over the ordered kex fields (RFC 5656 §4).
    static func exchangeHash(
        clientVersion: String, serverVersion: String,
        clientKexInit: Data, serverKexInit: Data,
        hostKey: Data, clientEphemeral: Data, serverEphemeral: Data,
        sharedSecretMPInt: Data
    ) -> Data {
        var buffer = Data()
        SSHWire.putString(clientVersion, into: &buffer)
        SSHWire.putString(serverVersion, into: &buffer)
        SSHWire.putString(clientKexInit, into: &buffer)
        SSHWire.putString(serverKexInit, into: &buffer)
        SSHWire.putString(hostKey, into: &buffer)
        SSHWire.putString(clientEphemeral, into: &buffer)
        SSHWire.putString(serverEphemeral, into: &buffer)
        buffer.append(sharedSecretMPInt)   // already length-prefixed by putMPInt
        return Data(SHA256.hash(data: buffer))
    }

    /// Derives one key stream (RFC 4253 §7.2): HASH(K || H || letter || id),
    /// extended by re-hashing K || H || sofar until `length` bytes exist.
    static func deriveKey(
        letter: UInt8, length: Int,
        sharedSecretMPInt K: Data, exchangeHash H: Data, sessionID: Data
    ) -> Data {
        var key = Data(SHA256.hash(data: K + H + Data([letter]) + sessionID))
        while key.count < length {
            key.append(Data(SHA256.hash(data: K + H + key)))
        }
        return key.prefix(length)
    }

    /// mpint magnitude bytes (strip leading zeros) for the shared secret, so
    /// the caller can pass it to both the hash and the KDF consistently.
    static func mpint(_ magnitude: Data) -> Data {
        var buffer = Data()
        SSHWire.putMPInt(magnitude, into: &buffer)
        return buffer
    }

    // MARK: - Host key signature verification

    /// Verifies the server's signature over the exchange hash with the host
    /// key it presented. Returns false for any parse error or unknown type.
    static func verifyHostKey(blob: Data, signature: Data, over hash: Data) -> Bool {
        var keyReader = SSHWire.Reader(blob)
        guard let keyType = keyReader.readStringUTF8() else { return false }
        var sigReader = SSHWire.Reader(signature)
        guard let sigType = sigReader.readStringUTF8(),
              let sigBlob = sigReader.readString() else { return false }

        switch keyType {
        case "ssh-ed25519":
            guard sigType == "ssh-ed25519",
                  let pub = keyReader.readString(),
                  let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pub) else { return false }
            return key.isValidSignature(sigBlob, for: hash)

        case "ecdsa-sha2-nistp256":
            guard sigType == "ecdsa-sha2-nistp256",
                  keyReader.readString() != nil,                // curve name
                  let point = keyReader.readString(),
                  let key = try? P256.Signing.PublicKey(x963Representation: point) else { return false }
            // The ecdsa signature blob is itself string(mpint r) || string(mpint s).
            var inner = SSHWire.Reader(sigBlob)
            guard let r = inner.readString(), let s = inner.readString(),
                  let raw = try? P256.Signing.ECDSASignature(rawRepresentation: pad32(r) + pad32(s)) else { return false }
            return key.isValidSignature(raw, for: hash)

        case "ssh-rsa":
            return verifyRSA(keyReader: &keyReader, sigType: sigType, signature: sigBlob, hash: hash)

        default:
            return false
        }
    }

    /// Left-pads (or trims) an mpint magnitude to exactly 32 bytes for the
    /// fixed-width raw ECDSA representation CryptoKit expects.
    private static func pad32(_ value: Data) -> Data {
        var bytes = Array(value)
        while bytes.first == 0 { bytes.removeFirst() }
        if bytes.count >= 32 { return Data(bytes.suffix(32)) }
        return Data(repeating: 0, count: 32 - bytes.count) + Data(bytes)
    }

    private static func verifyRSA(
        keyReader: inout SSHWire.Reader, sigType: String, signature: Data, hash: Data
    ) -> Bool {
        #if canImport(Security)
        guard let e = keyReader.readString(), let n = keyReader.readString() else { return false }
        // RSAPublicKey ::= SEQUENCE { modulus INTEGER, publicExponent INTEGER }
        let der = derSequence([derInteger(n), derInteger(e)])
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil) else { return false }
        let algorithm: SecKeyAlgorithm
        switch sigType {
        case "rsa-sha2-256": algorithm = .rsaSignatureMessagePKCS1v15SHA256
        case "rsa-sha2-512": algorithm = .rsaSignatureMessagePKCS1v15SHA512
        default: return false
        }
        return SecKeyVerifySignature(key, algorithm, hash as CFData, signature as CFData, nil)
        #else
        return false
        #endif
    }

    // MARK: - Minimal DER

    private static func derLength(_ count: Int) -> Data {
        if count < 0x80 { return Data([UInt8(count)]) }
        var bytes: [UInt8] = []
        var value = count
        while value > 0 { bytes.insert(UInt8(value & 0xFF), at: 0); value >>= 8 }
        return Data([0x80 | UInt8(bytes.count)] + bytes)
    }

    private static func derInteger(_ magnitude: Data) -> Data {
        var bytes = Array(magnitude)
        while bytes.first == 0 { bytes.removeFirst() }
        if bytes.isEmpty { bytes = [0] }
        if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }   // keep it positive
        return Data([0x02]) + derLength(bytes.count) + Data(bytes)
    }

    private static func derSequence(_ elements: [Data]) -> Data {
        let body = elements.reduce(Data(), +)
        return Data([0x30]) + derLength(body.count) + body
    }
}

/// AES-256-GCM packet cipher for `aes256-gcm@openssh.com` (RFC 5647): a
/// 12-byte nonce of a fixed 4-byte prefix plus an 8-byte invocation counter
/// that increments after every packet.
struct SSHGCMCipher {
    private let key: SymmetricKey
    private let fixed: Data           // 4 bytes
    private var counter: UInt64       // 8-byte invocation counter

    init(key: Data, iv: Data) {
        self.key = SymmetricKey(data: key)
        self.fixed = iv.prefix(4)
        self.counter = iv.dropFirst(4).prefix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private mutating func nextNonce() -> Data {
        var nonce = Data(fixed)
        var value = counter
        var tail = [UInt8](repeating: 0, count: 8)
        for index in stride(from: 7, through: 0, by: -1) {
            tail[index] = UInt8(value & 0xFF); value >>= 8
        }
        nonce.append(contentsOf: tail)
        counter &+= 1
        return nonce
    }

    /// Seals `plaintext` (padding_length || payload || padding) with the
    /// 4-byte `lengthField` as additional data. Returns ciphertext || tag.
    mutating func seal(plaintext: Data, lengthField: Data) -> Data? {
        guard let box = try? AES.GCM.seal(
            plaintext, using: key,
            nonce: try AES.GCM.Nonce(data: nextNonce()),
            authenticating: lengthField
        ) else { return nil }
        return box.ciphertext + box.tag
    }

    /// Opens `ciphertext` + 16-byte `tag` authenticated by `lengthField`.
    mutating func open(ciphertext: Data, tag: Data, lengthField: Data) -> Data? {
        guard let box = try? AES.GCM.SealedBox(
            nonce: try AES.GCM.Nonce(data: nextNonce()),
            ciphertext: ciphertext, tag: tag
        ) else { return nil }
        return try? AES.GCM.open(box, using: key, authenticating: lengthField)
    }
}
