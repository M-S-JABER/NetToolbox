import Foundation

/// Pure base conversion between binary, octal, decimal and hex (up to 64
/// bits). Unit-tested.
enum NumberConverter {
    struct Result: Equatable, Sendable {
        let binary: String
        let octal: String
        let decimal: String
        let hex: String
    }

    enum ConvertError: LocalizedError, Equatable {
        case empty
        case invalid
        case overflow

        var errorDescription: String? {
            switch self {
            case .empty: nil
            case .invalid: String(localized: "error.number.invalid", bundle: .module)
            case .overflow: String(localized: "error.number.overflow", bundle: .module)
            }
        }
    }

    /// Parses a value, auto-detecting the base from a `0x` / `0b` / `0o`
    /// prefix and defaulting to decimal.
    static func parse(_ text: String) throws -> UInt64 {
        var trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { throw ConvertError.empty }

        var radix = 10
        if trimmed.hasPrefix("0x") { radix = 16; trimmed.removeFirst(2) }
        else if trimmed.hasPrefix("0b") { radix = 2; trimmed.removeFirst(2) }
        else if trimmed.hasPrefix("0o") { radix = 8; trimmed.removeFirst(2) }
        trimmed = trimmed.replacingOccurrences(of: "_", with: "")
        guard !trimmed.isEmpty else { throw ConvertError.invalid }

        guard let value = UInt64(trimmed, radix: radix) else {
            // Distinguish overflow from bad characters.
            let allowed = "0123456789abcdef".prefix(radix)
            if trimmed.allSatisfy({ allowed.contains($0) }) {
                throw ConvertError.overflow
            }
            throw ConvertError.invalid
        }
        return value
    }

    static func format(_ value: UInt64) -> Result {
        Result(
            binary: grouped(String(value, radix: 2), size: 4),
            octal: String(value, radix: 8),
            decimal: String(value),
            hex: String(value, radix: 16).uppercased()
        )
    }

    /// Groups a binary string into nibbles for readability ("11010" → "1 1010").
    static func grouped(_ text: String, size: Int) -> String {
        guard size > 0, text.count > size else { return text }
        var result = ""
        let reversed = Array(text.reversed())
        for (index, character) in reversed.enumerated() {
            if index > 0, index % size == 0 { result.append(" ") }
            result.append(character)
        }
        return String(result.reversed())
    }
}
