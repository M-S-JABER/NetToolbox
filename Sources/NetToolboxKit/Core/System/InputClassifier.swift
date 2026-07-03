import Foundation

/// Classifies free-text the user types into the home search so the app can
/// suggest the most relevant tool ("looks like an IP → Subnet Calculator").
/// Pure and unit-tested.
enum InputClassifier {
    enum Kind: Equatable, Sendable {
        case ipv4
        case ipv6
        case mac
        case url
        case domain
        case none

        /// The tool the suggestion links to.
        var suggestedToolID: String? {
            switch self {
            case .ipv4, .ipv6: "subnet-calculator"
            case .mac: "mac-lookup"
            case .url: "http-headers"
            case .domain: "dns-lookup"
            case .none: nil
            }
        }

        var messageKey: String? {
            switch self {
            case .ipv4: "smart.ipv4"
            case .ipv6: "smart.ipv6"
            case .mac: "smart.mac"
            case .url: "smart.url"
            case .domain: "smart.domain"
            case .none: nil
            }
        }
    }

    static func classify(_ text: String) -> Kind {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return .none }
        let lower = trimmed.lowercased()

        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return .url }
        if isIPv4(lower) { return .ipv4 }
        if isMAC(lower) { return .mac }
        if lower.contains(":") && isIPv6(lower) { return .ipv6 }
        if isDomain(lower) { return .domain }
        return .none
    }

    static func isIPv4(_ text: String) -> Bool {
        let core = text.split(separator: "/").first.map(String.init) ?? text
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isNumber) && (Int(part) ?? 999) <= 255
        }
    }

    static func isIPv6(_ text: String) -> Bool {
        let core = text.split(separator: "/").first.map(String.init) ?? text
        guard core.contains(":") else { return false }
        let allowed = Set("0123456789abcdef:")
        return core.allSatisfy { allowed.contains($0) } && core.filter { $0 == ":" }.count >= 2
    }

    static func isMAC(_ text: String) -> Bool {
        let separators = CharacterSet(charactersIn: ":-.")
        let hex = text.components(separatedBy: separators).joined()
        return hex.count == 12 && hex.allSatisfy(\.isHexDigit)
    }

    static func isDomain(_ text: String) -> Bool {
        guard !text.contains(" "), text.contains("."), !text.hasPrefix("."), !text.hasSuffix(".") else {
            return false
        }
        let labels = text.split(separator: ".")
        guard labels.count >= 2, let tld = labels.last, tld.count >= 2 else { return false }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        return text.allSatisfy { allowed.contains($0) || $0 == "." }
    }
}
