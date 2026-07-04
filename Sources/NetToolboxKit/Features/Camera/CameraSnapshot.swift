import Foundation
import CryptoKit

/// Fetches a still JPEG from an ONVIF snapshot URI, handling HTTP Basic and
/// Digest authentication (cameras commonly protect the snapshot endpoint).
struct SnapshotFetcher: Sendable {
    let username: String
    let password: String

    func fetch(_ uri: String) async throws -> Data {
        guard let url = URL(string: uri) else { throw ONVIFError.network }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        var (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let challenge = http.value(forHTTPHeaderField: "WWW-Authenticate") ?? ""
            if let authorization = authorization(for: challenge, method: "GET", url: url) {
                request.setValue(authorization, forHTTPHeaderField: "Authorization")
                (data, response) = try await URLSession.shared.data(for: request)
            }
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !data.isEmpty else {
            throw ONVIFError.unauthorized
        }
        return data
    }

    private func authorization(for challenge: String, method: String, url: URL) -> String? {
        guard !username.isEmpty || !password.isEmpty else { return nil }
        if challenge.lowercased().hasPrefix("basic") {
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            return "Basic \(credentials)"
        }
        guard challenge.lowercased().contains("digest"),
              let realm = param(in: challenge, key: "realm"),
              let nonce = param(in: challenge, key: "nonce") else { return nil }
        let requestURI = url.path + (url.query.map { "?\($0)" } ?? "")
        let ha1 = md5("\(username):\(realm):\(password)")
        let ha2 = md5("\(method):\(requestURI)")
        if let qop = param(in: challenge, key: "qop"), qop.contains("auth") {
            let nc = "00000001"
            let cnonce = String(format: "%08x", UInt32.random(in: 0 ... UInt32.max))
            let response = md5("\(ha1):\(nonce):\(nc):\(cnonce):auth:\(ha2)")
            return "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(requestURI)\", response=\"\(response)\", algorithm=MD5, qop=auth, nc=\(nc), cnonce=\"\(cnonce)\""
        }
        let response = md5("\(ha1):\(nonce):\(ha2)")
        return "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(requestURI)\", response=\"\(response)\", algorithm=MD5"
    }

    private func md5(_ string: String) -> String {
        Insecure.MD5.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func param(in source: String, key: String) -> String? {
        guard let keyRange = source.range(of: "\(key)=", options: .caseInsensitive) else { return nil }
        var rest = source[keyRange.upperBound...]
        if rest.first == "\"" {
            rest = rest.dropFirst()
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            return String(rest[..<end])
        }
        let end = rest.firstIndex(where: { $0 == "," || $0 == " " }) ?? rest.endIndex
        return String(rest[..<end])
    }
}
