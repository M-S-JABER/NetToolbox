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
    /// Several concurrent transfers keep a fast link saturated (a single
    /// HTTP/2 stream can't), so the reading isn't underestimated.
    private let parallelStreams = 3

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
        // Stream the response body (not whole buffers) across several parallel
        // connections. Streaming lets a sampler report throughput continuously —
        // every 200 ms — instead of only at multi-megabyte chunk boundaries
        // (the old approach emitted a live figure at most a couple of times per
        // test, so the number appeared frozen). The parallel streams keep a
        // fast link saturated so the reading isn't underestimated.
        let chunkBytes = 100_000_000
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=\(chunkBytes)") else {
            throw NetworkServiceError.invalidURL
        }
        let counter = TransferCounter()
        let snapshot = WarmupSnapshot()
        let clock = ContinuousClock()
        let start = clock.now
        let sampler = liveSampler(counter: counter, snapshot: snapshot, start: start, clock: clock, live: live)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<parallelStreams {
                group.addTask {
                    let session = self.session
                    while Self.seconds(clock.now - start) < downloadSeconds, !Task.isCancelled {
                        do {
                            let (stream, response) = try await session.bytes(from: url)
                            if let http = response as? HTTPURLResponse, http.statusCode >= 400 { break }
                            var sinceFlush = 0
                            for try await _ in stream {
                                sinceFlush += 1
                                if sinceFlush >= 65_536 {
                                    counter.add(sinceFlush)
                                    sinceFlush = 0
                                    if Self.seconds(clock.now - start) >= downloadSeconds { break }
                                }
                            }
                            counter.add(sinceFlush)
                        } catch {
                            break
                        }
                    }
                }
            }
        }
        sampler.cancel()
        return try Self.throughput(totalBytes: counter.bytes, snapshot: snapshot, start: start, clock: clock)
    }

    // MARK: - Upload

    private func measureUpload(live: @escaping @Sendable (Double) -> Void) async throws -> Double {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { throw NetworkServiceError.invalidURL }
        // Small bodies uploaded back-to-back across parallel streams: each
        // completion advances the shared counter often enough for the sampler
        // to show a moving figure, and the parallel streams saturate the uplink.
        let payload = Data(count: 1_000_000)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let counter = TransferCounter()
        let snapshot = WarmupSnapshot()
        let clock = ContinuousClock()
        let start = clock.now
        let sampler = liveSampler(counter: counter, snapshot: snapshot, start: start, clock: clock, live: live)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<parallelStreams {
                let request = request
                let payload = payload
                group.addTask {
                    let session = self.session
                    while Self.seconds(clock.now - start) < uploadSeconds, !Task.isCancelled {
                        do {
                            _ = try await session.upload(for: request, from: payload)
                            counter.add(payload.count)
                        } catch {
                            break
                        }
                    }
                }
            }
        }
        sampler.cancel()
        return try Self.throughput(totalBytes: counter.bytes, snapshot: snapshot, start: start, clock: clock)
    }

    // MARK: - Live sampling

    /// Samples the shared byte counter every 200 ms and emits a live Mbps
    /// figure from the delta, and records a one-time snapshot at the end of
    /// warmup so the final figure can exclude connection ramp-up.
    private func liveSampler(
        counter: TransferCounter, snapshot: WarmupSnapshot,
        start: ContinuousClock.Instant, clock: ContinuousClock,
        live: @escaping @Sendable (Double) -> Void
    ) -> Task<Void, Never> {
        let warmup = warmupSeconds
        return Task {
            var lastBytes = 0
            var lastTime = start
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                let now = clock.now
                let bytes = counter.bytes
                let dt = Self.seconds(now - lastTime)
                if dt > 0 {
                    live(Double(bytes - lastBytes) * 8 / dt / 1_000_000)
                }
                lastBytes = bytes
                lastTime = now
                if Self.seconds(now - start) >= warmup {
                    snapshot.setIfNeeded(bytes: bytes, at: now)
                }
            }
        }
    }

    /// Computes throughput over the measured window (everything after warmup).
    private static func throughput(
        totalBytes: Int, snapshot: WarmupSnapshot,
        start: ContinuousClock.Instant, clock: ContinuousClock
    ) throws -> Double {
        let end = clock.now
        let measuredStart = snapshot.instant ?? start
        let measuredBytes = totalBytes - snapshot.bytes
        let windowSeconds = seconds(end - measuredStart)
        let effectiveSeconds = windowSeconds > 0 ? windowSeconds : seconds(end - start)
        let effectiveBytes = measuredBytes > 0 ? measuredBytes : totalBytes
        guard effectiveSeconds > 0, effectiveBytes > 0 else { throw NetworkServiceError.decoding }
        return Double(effectiveBytes) * 8 / effectiveSeconds / 1_000_000
    }

    // MARK: - Helpers

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
    }
}

/// Thread-safe byte accumulator shared across the parallel transfer streams
/// and read by the live sampler.
private final class TransferCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func add(_ n: Int) { lock.lock(); value += n; lock.unlock() }
    var bytes: Int { lock.lock(); defer { lock.unlock() }; return value }
}

/// Captures the byte total and instant at the end of warmup, exactly once, so
/// the final throughput can exclude the connection ramp-up window.
private final class WarmupSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var _bytes = 0
    private var _instant: ContinuousClock.Instant?
    var bytes: Int { lock.lock(); defer { lock.unlock() }; return _bytes }
    var instant: ContinuousClock.Instant? { lock.lock(); defer { lock.unlock() }; return _instant }
    func setIfNeeded(bytes: Int, at instant: ContinuousClock.Instant) {
        lock.lock(); defer { lock.unlock() }
        if _instant == nil { _bytes = bytes; _instant = instant }
    }
}
