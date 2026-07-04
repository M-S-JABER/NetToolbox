import Foundation

/// An AS number with its holder name.
struct ASNHolder: Identifiable, Equatable, Sendable {
    let asn: Int
    let holder: String
    var id: Int { asn }
}

/// Result of an ASN lookup.
struct ASNResult: Sendable {
    let asn: String
    let holder: String
    let type: String
    var prefixes: [String]
    var neighbours: Int
}

/// Result of an IP / prefix BGP lookup.
struct IPBGPResult: Sendable {
    let query: String
    let prefix: String
    let origins: [ASNHolder]
}

enum BGPError: LocalizedError {
    case badInput
    case network
    case decode

    var errorDescription: String? {
        switch self {
        case .badInput: return L10nString("bgp.error.badInput")
        case .network: return L10nString("bgp.error.network")
        case .decode: return L10nString("bgp.error.decode")
        }
    }
}

/// Global routing (BGP) lookups via the public **RIPEstat** data API — no
/// key, no external libraries, just HTTPS + JSON. Covers ASN overview /
/// announced prefixes / neighbours and IP→origin-AS resolution.
struct BGPService: Sendable {
    private struct Envelope<T: Decodable>: Decodable { let data: T }

    private func get<T: Decodable>(_ call: String, resource: String) async throws -> T {
        guard var components = URLComponents(string: "https://stat.ripe.net/data/\(call)/data.json") else {
            throw BGPError.network
        }
        components.queryItems = [
            URLQueryItem(name: "resource", value: resource),
            URLQueryItem(name: "sourceapp", value: "nettoolbox"),
        ]
        guard let url = components.url else { throw BGPError.badInput }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw BGPError.network }
        do {
            return try JSONDecoder().decode(Envelope<T>.self, from: data).data
        } catch {
            throw BGPError.decode
        }
    }

    /// Looks up an AS number (accepts "AS15169", "as15169" or "15169").
    func lookupASN(_ input: String) async throws -> ASNResult {
        let asn = Self.normalizeASN(input)
        guard asn.count > 2 else { throw BGPError.badInput }

        struct Overview: Decodable { let holder: String?; let type: String? }
        struct Prefixes: Decodable { struct Row: Decodable { let prefix: String }; let prefixes: [Row] }
        struct Neighbours: Decodable { struct Row: Decodable { let asn: Int? }; let neighbours: [Row] }

        let overview: Overview = try await get("as-overview", resource: asn)
        let prefixes: Prefixes = try await get("announced-prefixes", resource: asn)
        let neighbours: Neighbours = (try? await get("asn-neighbours", resource: asn)) ?? Neighbours(neighbours: [])

        return ASNResult(
            asn: asn,
            holder: overview.holder ?? "—",
            type: overview.type ?? "—",
            prefixes: prefixes.prefixes.map(\.prefix),
            neighbours: neighbours.neighbours.count
        )
    }

    /// Resolves an IP (or prefix) to its covering prefix and origin AS(es).
    func lookupIP(_ input: String) async throws -> IPBGPResult {
        let resource = input.trimmingCharacters(in: .whitespaces)
        guard !resource.isEmpty else { throw BGPError.badInput }

        struct NetInfo: Decodable { let prefix: String?; let asns: [Int]? }
        let net: NetInfo = try await get("network-info", resource: resource)
        let prefix = net.prefix ?? "—"

        struct PrefixOverview: Decodable {
            struct Row: Decodable { let asn: Int?; let holder: String? }
            let asns: [Row]?
        }
        var origins: [ASNHolder] = []
        if prefix != "—", let overview: PrefixOverview = try? await get("prefix-overview", resource: prefix),
           let rows = overview.asns {
            origins = rows.compactMap { row in row.asn.map { ASNHolder(asn: $0, holder: row.holder ?? "—") } }
        }
        if origins.isEmpty, let asns = net.asns {
            origins = asns.map { ASNHolder(asn: $0, holder: "—") }
        }

        return IPBGPResult(query: resource, prefix: prefix, origins: origins)
    }

    /// "AS15169" ← "as15169" / "15169" / " AS 15169 ".
    static func normalizeASN(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespaces).uppercased()
        if text.hasPrefix("AS") { text.removeFirst(2) }
        return "AS" + text.filter(\.isNumber)
    }
}
