import SwiftUI
import Observation

/// Where the test's traffic terminates (a Cloudflare edge) plus the client's
/// ISP, from the `/meta` endpoint.
struct SpeedServerInfo: Sendable, Equatable {
    var ip = ""
    var isp = ""
    var location = ""
    var colo = ""
}

/// Progress events streamed from the engine as the test runs.
enum SpeedUpdate: Sendable {
    case phase(SpeedPhase)
    case server(SpeedServerInfo)
    case latency(ms: Double, jitter: Double)
    case liveDownload(Double)
    case liveUpload(Double)
    case finalDownload(Double)
    case finalUpload(Double)
}

enum SpeedPhase: Sendable, Equatable {
    case idle
    case latency
    case download
    case upload
    case finished
    case failed(String)
}

/// A multi-metric speed test (latency, jitter, download, upload) built on
/// Cloudflare's open, key-less speed endpoints — the same infrastructure that
/// backs speed.cloudflare.com. No external SDK.
struct CloudflareSpeedEngine: Sendable {
    private let downloadSeconds = 8.0
    private let uploadSeconds = 6.0
    private let warmupSeconds = 1.0

    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: configuration)
    }

    func stream() -> AsyncThrowingStream<SpeedUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if let server = try? await fetchMeta() {
                        continuation.yield(.server(server))
                    }

                    continuation.yield(.phase(.latency))
                    let (ping, jitter) = try await measureLatency()
                    continuation.yield(.latency(ms: ping, jitter: jitter))

                    continuation.yield(.phase(.download))
                    let download = try await measureDownload { continuation.yield(.liveDownload($0)) }
                    continuation.yield(.finalDownload(download))

                    continuation.yield(.phase(.upload))
                    let upload = try await measureUpload { continuation.yield(.liveUpload($0)) }
                    continuation.yield(.finalUpload(upload))

                    continuation.yield(.phase(.finished))
                    continuation.finish()
                } catch {
                    continuation.yield(.phase(.failed(error.localizedDescription)))
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Metadata

    private func fetchMeta() async throws -> SpeedServerInfo {
        guard let url = URL(string: "https://speed.cloudflare.com/meta") else { throw NetworkServiceError.invalidURL }
        let (data, _) = try await session.data(from: url)
        struct Meta: Decodable {
            let clientIp: String?
            let asOrganization: String?
            let colo: String?
            let city: String?
            let country: String?
        }
        let meta = try JSONDecoder().decode(Meta.self, from: data)
        let location = [meta.city, meta.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return SpeedServerInfo(
            ip: meta.clientIp ?? "",
            isp: meta.asOrganization ?? "",
            location: location,
            colo: meta.colo ?? ""
        )
    }

    // MARK: - Latency + jitter

    private func measureLatency() async throws -> (ping: Double, jitter: Double) {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else { throw NetworkServiceError.invalidURL }
        let session = self.session
        let clock = ContinuousClock()
        var samples: [Double] = []
        for index in 0..<12 {
            if Task.isCancelled { break }
            let start = clock.now
            _ = try await session.data(from: url)
            let rtt = Self.seconds(clock.now - start) * 1000
            // Drop the first sample — it pays TLS/connection setup.
            if index > 0 { samples.append(rtt) }
        }
        guard !samples.isEmpty else { throw NetworkServiceError.decoding }
        let ping = samples.min() ?? 0
        var deltas: [Double] = []
        for i in 1..<max(1, samples.count) {
            deltas.append(abs(samples[i] - samples[i - 1]))
        }
        let jitter = deltas.isEmpty ? 0 : deltas.reduce(0, +) / Double(deltas.count)
        return (ping, jitter)
    }

    // MARK: - Download

    private func measureDownload(live: @escaping @Sendable (Double) -> Void) async throws -> Double {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=300000000") else { throw NetworkServiceError.invalidURL }
        let probe = ThroughputProbe()
        let session = URLSession(configuration: sessionConfig(), delegate: probe, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let clock = ContinuousClock()
        let start = clock.now
        probe.begin()
        session.dataTask(with: url).resume()

        var warmupBytes = 0
        var warmupTime = start
        var warmupDone = false
        var lastBytes = 0
        var lastTime = start

        while true {
            try? await Task.sleep(for: .milliseconds(200))
            if Task.isCancelled { break }
            let now = clock.now
            let elapsed = Self.seconds(now - start)
            let bytes = probe.received

            if !warmupDone, elapsed >= warmupSeconds {
                warmupBytes = bytes
                warmupTime = now
                warmupDone = true
            }
            let interval = Self.seconds(now - lastTime)
            if interval > 0 {
                live(Double(bytes - lastBytes) * 8 / interval / 1_000_000)
            }
            lastBytes = bytes
            lastTime = now

            // Keep the pipe full if a payload finished before the window closed.
            if probe.isCompleted, elapsed < downloadSeconds {
                probe.begin()
                session.dataTask(with: url).resume()
            }
            if elapsed >= downloadSeconds { break }
        }

        let measuredSeconds = Self.seconds(clock.now - warmupTime)
        let measuredBytes = probe.received - warmupBytes
        guard measuredSeconds > 0, measuredBytes > 0 else { throw NetworkServiceError.decoding }
        return Double(measuredBytes) * 8 / measuredSeconds / 1_000_000
    }

    // MARK: - Upload

    private func measureUpload(live: @escaping @Sendable (Double) -> Void) async throws -> Double {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { throw NetworkServiceError.invalidURL }
        let payload = Data(count: 4_000_000)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let session = self.session
        let clock = ContinuousClock()
        let start = clock.now
        var total = 0
        var warmupBytes = 0
        var warmupTime = start
        var warmupDone = false

        while true {
            if Task.isCancelled { break }
            let elapsed = Self.seconds(clock.now - start)
            if elapsed >= uploadSeconds { break }
            _ = try await session.upload(for: request, from: payload)
            total += payload.count
            let now = clock.now
            let done = Self.seconds(now - start)
            if !warmupDone, done >= warmupSeconds {
                warmupBytes = total
                warmupTime = now
                warmupDone = true
            }
            let measured = Self.seconds(now - (warmupDone ? warmupTime : start))
            if measured > 0 {
                live(Double(total - warmupBytes) * 8 / measured / 1_000_000)
            }
        }

        let measuredSeconds = Self.seconds(clock.now - warmupTime)
        let measuredBytes = total - warmupBytes
        let seconds = measuredSeconds > 0 ? measuredSeconds : Self.seconds(clock.now - start)
        let bytes = measuredBytes > 0 ? measuredBytes : total
        guard seconds > 0, bytes > 0 else { throw NetworkServiceError.decoding }
        return Double(bytes) * 8 / seconds / 1_000_000
    }

    // MARK: - Helpers

    private func sessionConfig() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return configuration
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    }
}

/// Accumulates received bytes for a delegate-driven download so throughput can
/// be sampled live without iterating the stream byte by byte.
private final class ThroughputProbe: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var total = 0
    private var completed = false

    var received: Int {
        lock.lock(); defer { lock.unlock() }
        return total
    }

    var isCompleted: Bool {
        lock.lock(); defer { lock.unlock() }
        return completed
    }

    func begin() {
        lock.lock(); completed = false; lock.unlock()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock(); total += data.count; lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); completed = true; lock.unlock()
    }
}
