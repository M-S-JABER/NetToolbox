import Foundation
import Observation

/// State holder for MAC lookup; parsing is in `MACAddress`,
/// vendor data behind `OUIProviding` for easy replacement/mocking.
@MainActor
@Observable
final class MACLookupViewModel {
    struct LookupResult: Equatable {
        let normalized: String
        let ciscoNotation: String
        let oui: String
        let vendor: String?
        let isMulticast: Bool
        let isLocallyAdministered: Bool
    }

    enum Output: Equatable {
        case idle
        case success(LookupResult)
        case failure(String)
    }

    var input = ""
    private(set) var output: Output = .idle

    private let database: any OUIProviding

    init(database: any OUIProviding = BundledOUIDatabase()) {
        self.database = database
    }

    func lookup() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            output = .idle
            return
        }

        do {
            let mac = try MACAddress(parsing: text)
            output = .success(
                LookupResult(
                    normalized: mac.normalized,
                    ciscoNotation: mac.ciscoNotation,
                    oui: mac.ouiKey,
                    vendor: database.vendor(forOUI: mac.ouiKey),
                    isMulticast: mac.isMulticast,
                    isLocallyAdministered: mac.isLocallyAdministered
                )
            )
        } catch {
            output = .failure(error.localizedDescription)
        }
    }

    func clear() {
        input = ""
        output = .idle
    }
}
