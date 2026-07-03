import Foundation

/// Vendor lookup interface — swappable (bundled JSON now, full IEEE
/// registry or a remote API later).
protocol OUIProviding: Sendable {
    func vendor(forOUI key: String) -> String?
}

/// Offline OUI database loaded from the bundled `oui.json`
/// (an abridged registry of well-known vendors).
/// Loading is lazy and happens once; lookups are O(1).
struct BundledOUIDatabase: OUIProviding {
    private let vendors: [String: String]

    init() {
        // SwiftPM places processed resources in the generated module bundle.
        self.init(loading: Bundle.module)
    }

    init(loading bundle: Bundle) {
        guard let url = bundle.url(forResource: "oui", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            vendors = [:]
            return
        }
        vendors = decoded
    }

    init(vendors: [String: String]) {
        self.vendors = vendors
    }

    func vendor(forOUI key: String) -> String? {
        vendors[key.uppercased()]
    }

    var count: Int { vendors.count }
}
