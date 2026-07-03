import Foundation

/// Offline text transforms for the encoder/decoder tool. Pure and
/// unit-tested — no UI, no I/O.
enum TextConverter {
    enum Operation: String, CaseIterable, Identifiable, Sendable {
        case base64Encode, base64Decode
        case hexEncode, hexDecode
        case urlEncode, urlDecode

        var id: String { rawValue }
        var labelKey: String { "convert.op.\(rawValue)" }
    }

    enum ConvertError: LocalizedError, Equatable {
        case invalidBase64
        case invalidHex
        case invalidURLEncoding
        case notUTF8

        var errorDescription: String? {
            switch self {
            case .invalidBase64: String(localized: "error.convert.base64", bundle: .module)
            case .invalidHex: String(localized: "error.convert.hex", bundle: .module)
            case .invalidURLEncoding: String(localized: "error.convert.url", bundle: .module)
            case .notUTF8: String(localized: "error.convert.utf8", bundle: .module)
            }
        }
    }

    static func apply(_ operation: Operation, to input: String) throws -> String {
        switch operation {
        case .base64Encode:
            return Data(input.utf8).base64EncodedString()
        case .base64Decode:
            let cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = Data(base64Encoded: cleaned) else { throw ConvertError.invalidBase64 }
            guard let text = String(data: data, encoding: .utf8) else { throw ConvertError.notUTF8 }
            return text
        case .hexEncode:
            return Data(input.utf8).map { String(format: "%02x", $0) }.joined()
        case .hexDecode:
            return try hexDecode(input)
        case .urlEncode:
            let allowed = CharacterSet.alphanumerics
            return input.addingPercentEncoding(withAllowedCharacters: allowed) ?? input
        case .urlDecode:
            guard let decoded = input.removingPercentEncoding else {
                throw ConvertError.invalidURLEncoding
            }
            return decoded
        }
    }

    /// Decodes a hex string (ignoring spaces and a leading "0x") to UTF-8 text.
    static func hexDecode(_ input: String) throws -> String {
        var hex = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ":", with: "")
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") { hex.removeFirst(2) }
        guard hex.count % 2 == 0, hex.allSatisfy(\.isHexDigit) else {
            throw ConvertError.invalidHex
        }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw ConvertError.invalidHex
            }
            bytes.append(byte)
            index = next
        }
        guard let text = String(bytes: bytes, encoding: .utf8) else { throw ConvertError.notUTF8 }
        return text
    }
}
