import Foundation
import CryptoKit

/// Pure hashing and JWT-decoding helpers, all native (CryptoKit + Foundation).
/// No signature verification is performed on JWTs — decode/inspection only.
enum CryptoTools {
    struct Hashes: Sendable, Equatable {
        var md5: String
        var sha1: String
        var sha256: String
        var sha384: String
        var sha512: String
    }

    static func hashes(of text: String) -> Hashes {
        let data = Data(text.utf8)
        return Hashes(
            md5: hex(Insecure.MD5.hash(data: data)),
            sha1: hex(Insecure.SHA1.hash(data: data)),
            sha256: hex(SHA256.hash(data: data)),
            sha384: hex(SHA384.hash(data: data)),
            sha512: hex(SHA512.hash(data: data))
        )
    }

    struct JWT: Sendable, Equatable {
        var header: String
        var payload: String
        var algorithm: String
        var expiry: String
        var isExpired: Bool
    }

    /// Decodes a JWT's header and payload (base64url → pretty JSON). Returns nil
    /// if the token isn't at least `header.payload`.
    static func decodeJWT(_ token: String, now: Date = Date()) -> JWT? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".")
        guard parts.count >= 2,
              let headerData = base64urlDecode(parts[0]),
              let payloadData = base64urlDecode(parts[1]) else {
            return nil
        }

        var algorithm = "—"
        if let object = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
           let alg = object["alg"] as? String {
            algorithm = alg
        }

        var expiry = ""
        var isExpired = false
        if let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
           let exp = object["exp"] as? Double {
            let date = Date(timeIntervalSince1970: exp)
            expiry = date.formatted(date: .abbreviated, time: .shortened)
            isExpired = date < now
        }

        return JWT(
            header: prettyJSON(headerData),
            payload: prettyJSON(payloadData),
            algorithm: algorithm,
            expiry: expiry,
            isExpired: isExpired
        )
    }

    // MARK: - Helpers

    static func base64urlDecode(_ value: Substring) -> Data? {
        var string = String(value)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while string.count % 4 != 0 { string += "=" }
        return Data(base64Encoded: string)
    }

    private static func prettyJSON(_ data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return String(decoding: data, as: UTF8.self)
        }
        return String(decoding: pretty, as: UTF8.self)
    }

    private static func hex(_ digest: some Sequence<UInt8>) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
