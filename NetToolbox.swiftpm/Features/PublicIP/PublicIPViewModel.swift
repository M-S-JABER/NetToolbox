import Foundation
import Observation

/// Loads the public IP / ISP details and enumerates local addresses.
/// Both dependencies are injected behind protocols.
@MainActor
@Observable
final class PublicIPViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(PublicIPInfo)
        case failure(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var localAddresses: [LocalInterfaceAddress] = []

    private let service: any PublicIPProviding
    private let localProvider: any LocalIPProviding

    init(
        service: any PublicIPProviding = IpwhoisService(),
        localProvider: any LocalIPProviding = SystemLocalIPProvider()
    ) {
        self.service = service
        self.localProvider = localProvider
    }

    func refresh() async {
        localAddresses = localProvider.addresses()
        state = .loading
        do {
            let info = try await service.fetch()
            state = .loaded(info)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
