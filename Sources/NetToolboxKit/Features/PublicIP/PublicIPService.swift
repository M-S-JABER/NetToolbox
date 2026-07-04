import Foundation

/// Public IP + ISP details, provider-agnostic.
struct PublicIPInfo: Equatable, Sendable {
    let ip: String
    let country: String?
    let countryCode: String?
    let city: String?
    let isp: String?
    let organization: String?
    let asn: Int?
    let timezone: String?
    var latitude: Double? = nil
    var longitude: Double? = nil
}

/// Abstraction so the geo-IP provider can be swapped or mocked in tests.
protocol PublicIPProviding: Sendable {
    func fetch() async throws -> PublicIPInfo
}

/// `PublicIPProviding` backed by the free https://ipwho.is endpoint.
struct IpwhoisService: PublicIPProviding {
    private let client: any HTTPDataClient

    init(client: any HTTPDataClient = URLSessionDataClient()) {
        self.client = client
    }

    private struct Response: Decodable {
        struct Connection: Decodable {
            let asn: Int?
            let org: String?
            let isp: String?
        }
        struct Timezone: Decodable {
            let id: String?
        }
        let ip: String
        let success: Bool
        let country: String?
        let country_code: String?
        let city: String?
        let latitude: Double?
        let longitude: Double?
        let connection: Connection?
        let timezone: Timezone?
    }

    func fetch() async throws -> PublicIPInfo {
        guard let url = URL(string: "https://ipwho.is/") else {
            throw NetworkServiceError.invalidURL
        }
        let data = try await client.data(from: url)
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              decoded.success
        else { throw NetworkServiceError.decoding }

        return PublicIPInfo(
            ip: decoded.ip,
            country: decoded.country,
            countryCode: decoded.country_code,
            city: decoded.city,
            isp: decoded.connection?.isp,
            organization: decoded.connection?.org,
            asn: decoded.connection?.asn,
            timezone: decoded.timezone?.id,
            latitude: decoded.latitude,
            longitude: decoded.longitude
        )
    }
}
