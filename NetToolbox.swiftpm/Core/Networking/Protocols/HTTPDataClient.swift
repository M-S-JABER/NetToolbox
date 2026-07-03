import Foundation

/// Abstraction over HTTP fetching so services can be unit-tested with mocks
/// and the transport can be swapped without touching features.
protocol HTTPDataClient: Sendable {
    func data(from url: URL) async throws -> Data
}

/// Errors surfaced by networking services, with bilingual descriptions.
enum NetworkServiceError: LocalizedError {
    case invalidURL
    case badStatus(Int)
    case offline
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "error.network.invalidURL")
        case .badStatus(let code):
            String(localized: "error.network.badStatus") + " (\(code))"
        case .offline:
            String(localized: "error.network.offline")
        case .decoding:
            String(localized: "error.network.decoding")
        }
    }
}
