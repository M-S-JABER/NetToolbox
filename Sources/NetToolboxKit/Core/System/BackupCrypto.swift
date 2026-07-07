import Foundation
import CryptoKit
import CommonCrypto
import Security

/// Passphrase-based encryption for backup files, so exported data (which
/// includes SSH and camera credentials) is never written to disk in clear
/// text. Native only: PBKDF2-HMAC-SHA256 for key derivation + AES-256-GCM for
/// the sealed payload.
///
/// Container layout (all binary, concatenated):
///
///     "NTBX1"  magic          5 bytes
///     salt                    16 bytes
///     iterations              4 bytes, big-endian UInt32
///     AES-GCM sealed box      nonce (12) + ciphertext + tag (16)
enum BackupCrypto {
    static let magic = Data("NTBX1".utf8)
    static let iterations: UInt32 = 200_000

    enum CryptoError: Error, Equatable {
        case notEncrypted
        case corrupt
        case wrongPassword
        case keyDerivationFailed
    }

    /// True when `data` starts with the encrypted-container magic.
    static func isEncrypted(_ data: Data) -> Bool {
        data.starts(with: magic)
    }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        let salt = randomBytes(16)
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.corrupt }

        var out = Data()
        out.append(magic)
        out.append(salt)
        out.append(bigEndianBytes(iterations))
        out.append(combined)
        return out
    }

    static func decrypt(_ container: Data, password: String) throws -> Data {
        guard isEncrypted(container) else { throw CryptoError.notEncrypted }
        var cursor = magic.count
        func take(_ n: Int) throws -> Data {
            guard cursor + n <= container.count else { throw CryptoError.corrupt }
            let slice = container.subdata(in: cursor..<(cursor + n))
            cursor += n
            return slice
        }
        let salt = try take(16)
        let iterationData = try take(4)
        let iterations = iterationData.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard iterations > 0 else { throw CryptoError.corrupt }
        let sealedData = container.subdata(in: cursor..<container.count)

        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: sealedData)
            return try AES.GCM.open(box, using: key)
        } catch {
            // A bad passphrase surfaces as an authentication failure.
            throw CryptoError.wrongPassword
        }
    }

    // MARK: - Primitives

    private static func deriveKey(password: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var derived = Data(count: 32)
        let status = derived.withUnsafeMutableBytes { derivedPtr in
            salt.withUnsafeBytes { saltPtr in
                passwordData.withUnsafeBytes { passwordPtr in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPtr.baseAddress?.assumingMemoryBound(to: CChar.self),
                        passwordData.count,
                        saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        derivedPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = Data(count: count)
        _ = bytes.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return bytes
    }

    private static func bigEndianBytes(_ value: UInt32) -> Data {
        Data([UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
    }
}
