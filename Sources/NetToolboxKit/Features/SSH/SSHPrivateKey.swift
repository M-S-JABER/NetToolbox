import Foundation
import CryptoKit

/// A parsed unencrypted OpenSSH ed25519 private key ("openssh-key-v1"), used
/// for public-key authentication. Only ed25519 with no passphrase is
/// supported — that covers `ssh-keygen -t ed25519` keys created without a
/// passphrase, which is the common case for an iPad-managed key.
struct SSHPrivateKey: Sendable {
    private let signingKey: Curve25519.Signing.PrivateKey
    /// The public key blob: string("ssh-ed25519") || string(pub) — exactly
    /// what a userauth "publickey" request carries.
    let publicKeyBlob: Data

    /// Parses the PEM text of an OpenSSH private key. Returns nil if the text
    /// isn't an unencrypted ed25519 OpenSSH key.
    init?(pem: String) {
        let base64 = pem
            .split(whereSeparator: \.isNewline)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        guard let raw = Data(base64Encoded: base64) else { return nil }

        let magic = Array("openssh-key-v1\u{0}".utf8)
        guard raw.starts(with: magic) else { return nil }

        var reader = SSHWire.Reader(Data(raw.dropFirst(magic.count)))
        guard let cipher = reader.readStringUTF8(), cipher == "none",       // unencrypted only
              reader.readStringUTF8() != nil,                                // kdfname
              reader.readString() != nil,                                    // kdfoptions
              let keyCount = reader.readUInt32(), keyCount == 1,
              let pubBlob = reader.readString(),
              let privateSection = reader.readString() else { return nil }

        var priv = SSHWire.Reader(privateSection)
        guard priv.readUInt32() != nil,                                      // checkint1
              priv.readUInt32() != nil,                                      // checkint2
              let keyType = priv.readStringUTF8(), keyType == "ssh-ed25519",
              priv.readString() != nil,                                      // public key (32)
              let secret = priv.readString(), secret.count >= 32,            // seed(32) || pub(32)
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: secret.prefix(32)) else {
            return nil
        }

        self.signingKey = key
        self.publicKeyBlob = pubBlob
    }

    /// Signs the userauth data with ed25519 (raw 64-byte signature).
    func sign(_ data: Data) throws -> Data {
        try signingKey.signature(for: data)
    }
}
