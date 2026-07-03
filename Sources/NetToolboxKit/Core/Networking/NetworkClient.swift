import Foundation

/// Default `HTTPDataClient` backed by `URLSession` with an ephemeral,
/// short-timeout configuration suited to quick diagnostic calls.
struct URLSessionDataClient: HTTPDataClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func data(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw NetworkServiceError.badStatus(http.statusCode)
            }
            return data
        } catch let error as NetworkServiceError {
            throw error
        } catch let error as URLError where error.code == .notConnectedToInternet
            || error.code == .networkConnectionLost
            || error.code == .dataNotAllowed {
            throw NetworkServiceError.offline
        }
    }
}
