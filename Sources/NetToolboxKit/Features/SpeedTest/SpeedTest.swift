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
    case bufferbloat(idle: Double, loaded: Double, increase: Double, grade: String)
    case loss(Double)
}

/// Grades bufferbloat from the latency increase under load (Waveform-style).
enum BufferbloatGrade {
    static func grade(increaseMs delta: Double) -> String {
        switch delta {
        case ..<5: "A+"
        case ..<30: "A"
        case ..<60: "B"
        case ..<100: "C"
        case ..<200: "D"
        default: "F"
        }
    }
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
                    // Sample latency *under load* across the download+upload
                    // window to measure bufferbloat and probe-level loss.
                    async let loaded = sampleLoadedLatency(duration: downloadSeconds + uploadSeconds + 2)

                    let download = try await measureDownload { continuation.yield(.liveDownload($0)) }
                    continuation.yield(.finalDownload(download))

                    continuation.yield(.phase(.upload))
                    let upload = try await measureUpload { continuation.yield(.liveUpload($0)) }
                    continuation.yield(.finalUpload(upload))

                    let loadedResult = await loaded
                    if let loadedAvg = loadedResult.avg {
                        let increase = max(0, loadedAvg - ping)
                        continuation.yield(.bufferbloat(
                            idle: ping, loaded: loadedAvg, increase: increase,
                            grade: BufferbloatGrade.grade(increaseMs: increase)
                        ))
                    }
                    if loadedResult.sent > 0 {
                        continuation.yield(.loss(Double(loadedResult.failed) / Double(loadedResult.sent) * 100))
                    }

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

    /// Repeatedly measures latency while the throughput tests saturate the
    /// link, so we can report how much latency grows under load (bufferbloat)
    /// and how many probes are lost.
    private func sampleLoadedLatency(duration: Double) async -> (avg: Double?, sent: Int, failed: Int) {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=0") else { return (nil, 0, 0) }
        let session = self.session
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(duration))
        var samples: [Double] = []
        var sent = 0, failed = 0
        while clock.now < deadline {
            if Task.isCancelled { break }
            sent += 1
            let start = clock.now
            do {
                _ = try await session.data(from: url)
                samples.append(Self.seconds(clock.now - start) * 1000)
            } catch {
                failed += 1
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        let avg = samples.isEmpty ? nil : samples.reduce(0, +) / Double(samples.count)
        return (avg, sent, failed)
    }

    // MARK: - Download

    private func measureDownload(live: @escaping @Sendable (Double) -> Void) async throws -> Double {
        // Pull fixed-size chunks back-to-back with the same async API the upload
        // uses. URLSession keeps the HTTP/2 connection alive between chunks, so
        // throughput stays high — and unlike a delegate-driven session, this
        // works reliably inside the Swift Playgrounds preview sandbox.
        let chunkBytes = 20_000_000
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(chunkBytes)") else {
            throw NetworkServiceError.invalidURL
        }
        let session = self.session
        let clock = ContinuousClock()
        let start = clock.now
        var total = 0
        var warmupBytes = 0
        var warmupTime = start
        var warmupDone = false

        while true {
            if Task.isCancelled { break }
            if Self.seconds(clock.now - start) >= downloadSeconds { break }
            do {
                let (data, _) = try await session.data(from: url)
                total += data.count
            } catch {
                if total > 0 { break }   // slow link timed out mid-chunk — use what arrived
                throw error
            }
            let now = clock.now
            if !warmupDone, Self.seconds(now - start) >= warmupSeconds {
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

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    }
}
