import Foundation
import Observation

/// Trust-on-first-use record of SSH host-key fingerprints. On the first
/// connection to a host we remember its fingerprint; on later connections we
/// compare, so a changed key (a possible man-in-the-middle, or a legitimately
/// reinstalled server) is surfaced instead of silently accepted.
///
/// Stored in `UserDefaults` as `host:port → SHA256 fingerprint`.
@MainActor
@Observable
final class KnownHostsStore {
    /// How a presented fingerprint relates to what we've seen before.
    enum Trust: Sendable, Equatable {
        case new        // first time we've connected to this host
        case known      // matches the remembered fingerprint
        case changed    // differs from the remembered fingerprint — warn!
    }

    private let key = "nettoolbox.knownHosts"
    private(set) var fingerprints: [String: String]

    init() {
        let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        fingerprints = stored ?? [:]
    }

    private func identifier(host: String, port: String) -> String {
        "\(host.trimmingCharacters(in: .whitespaces).lowercased()):\(port.trimmingCharacters(in: .whitespaces))"
    }

    /// Evaluates a freshly-seen fingerprint. On first use it is remembered and
    /// reported as `.new`; a match is `.known`; a mismatch is `.changed` and the
    /// stored value is NOT overwritten (the user must accept it explicitly).
    func evaluate(host: String, port: String, fingerprint: String) -> Trust {
        guard !fingerprint.isEmpty else { return .new }
        let id = identifier(host: host, port: port)
        if let existing = fingerprints[id] {
            return existing == fingerprint ? .known : .changed
        }
        remember(id: id, fingerprint: fingerprint)
        return .new
    }

    /// Explicitly accept (or update) a host's fingerprint — used when the user
    /// confirms a changed key.
    func accept(host: String, port: String, fingerprint: String) {
        guard !fingerprint.isEmpty else { return }
        remember(id: identifier(host: host, port: port), fingerprint: fingerprint)
    }

    private func remember(id: String, fingerprint: String) {
        fingerprints[id] = fingerprint
        UserDefaults.standard.set(fingerprints, forKey: key)
    }
}
