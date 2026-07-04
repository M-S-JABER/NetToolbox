import Foundation

/// Extracts common fields from raw WHOIS text. Pure and unit-tested.
enum WhoisParser {
    struct Fields: Equatable, Sendable {
        var registrar: String?
        var created: String?
        var updated: String?
        var expires: String?
        var nameServers: [String] = []

        var hasAny: Bool {
            registrar != nil || created != nil || updated != nil || expires != nil || !nameServers.isEmpty
        }
    }

    static func parse(_ text: String) -> Fields {
        var fields = Fields()
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            switch key {
            case "registrar", "registrar name", "sponsoring registrar":
                if fields.registrar == nil { fields.registrar = value }
            case "creation date", "created", "created on", "registered on", "registration time":
                if fields.created == nil { fields.created = value }
            case "updated date", "last updated", "last modified", "modified":
                if fields.updated == nil { fields.updated = value }
            case "registry expiry date", "expiry date", "expiration date",
                 "registrar registration expiration date", "expire", "paid-till":
                if fields.expires == nil { fields.expires = value }
            case "name server", "nserver", "name servers":
                let server = value.split(separator: " ").first.map(String.init) ?? value
                if !fields.nameServers.contains(server) { fields.nameServers.append(server) }
            default:
                break
            }
        }
        return fields
    }
}
