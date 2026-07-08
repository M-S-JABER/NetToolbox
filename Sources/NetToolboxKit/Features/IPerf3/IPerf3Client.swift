import Foundation
import Network

/// A native iperf3 client over `Network.framework`, zero dependencies.
/// Implements the TCP control handshake (cookie, PARAM_EXCHANGE,
/// CREATE_STREAMS, TEST_START/RUNNING/END, EXCHANGE/DISPLAY_RESULTS) and a
/// single- or multi-stream TCP throughput test in either direction.
///
/// Scope: TCP only, authNoPriv-less (no `--rsa`/authentication), no UDP.
/// Aimed at a plain `iperf3 -s` server on the default port.
final class IPerf3Client: @unchecked Sendable {
    enum Event: Sendable {
        case connecting
        case running(mbps: Double, seconds: Double)
        case finished(mbps: Double, bytes: Int, seconds: Double)
        case failed(String)
    }

    struct Config: Sendable {
        var host: String
        var port: UInt16
        var seconds: Int
        var reverse: Bool          // true = download (server sends), false = upload
        var parallel: Int
    }

    private let config: Config
    private let cookie: [UInt8]
    private let queue = DispatchQueue(label: "com.nettoolbox.iperf3")
    private var control: NWConnection?
    private var streams: [NWConnection] = []
    private var controlBuffer = Data()

    private var transferred = 0
    private var startTime: Date?
    private var ticker: DispatchSourceTimer?
    private var durationTimer: DispatchSourceTimer?
    private var isDone = false
    private let block: [UInt8]

    var onEvent: ((Event) -> Void)?

    /// `sending` is true when this client is the data sender (upload/forward).
    private var sending: Bool { !config.reverse }

    init(config: Config) {
        self.config = config
        self.cookie = IPerf3Protocol.randomCookie()
        self.block = [UInt8](repeating: 0, count: IPerf3Protocol.blockSize)
    }

    // MARK: - Lifecycle

    func start() {
        guard let nwPort = NWEndpoint.Port(rawValue: config.port) else {
            emit(.failed("Invalid port")); return
        }
        emit(.connecting)
        let connection = NWConnection(host: NWEndpoint.Host(config.host), port: nwPort, using: .tcp)
        control = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.send(connection, Data(self.cookie))   // 37-byte cookie first
                self.readState()
            case .failed(let error), .waiting(let error):
                self.fail(error.localizedDescription)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func cancel() {
        queue.async { [weak self] in self?.teardown() }
    }

    private func teardown() {
        guard !isDone else { return }
        isDone = true
        ticker?.cancel(); ticker = nil
        durationTimer?.cancel(); durationTimer = nil
        control?.cancel(); control = nil
        streams.forEach { $0.cancel() }
        streams.removeAll()
    }

    // MARK: - Control channel

    /// Reads one control state byte and dispatches on it.
    private func readState() {
        guard let control, !isDone else { return }
        control.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error { self.fail(error.localizedDescription); return }
            guard let byte = data?.first else { self.fail("Control connection closed"); return }
            self.handle(state: byte)
        }
    }

    private func handle(state raw: UInt8) {
        guard let state = IPerf3Protocol.State(rawValue: raw) else {
            // Unknown/other states are advisory — keep reading.
            readState(); return
        }
        switch state {
        case .paramExchange:
            sendParameters()
            readState()
        case .createStreams:
            openStreams()
            readState()
        case .testStart:
            readState()
        case .testRunning:
            beginTransfer()
            readState()
        case .testEnd:
            // Server-driven end (reverse mode). Stop and move to results.
            finishTransfer()
            readState()
        case .exchangeResults:
            exchangeResults()
        case .displayResults:
            // Acknowledge, then the server sends IPERF_DONE.
            sendState(.displayResults)
            readState()
        case .iperfDone:
            complete()
        case .accessDenied:
            fail("Server busy — another test is running")
        case .serverError:
            fail("Server reported an error")
        case .serverTerminate, .clientTerminate:
            fail("Test terminated")
        case .iperfStart:
            readState()
        }
    }

    private func sendState(_ state: IPerf3Protocol.State) {
        guard let control else { return }
        send(control, Data([state.rawValue]))
    }

    private func sendParameters() {
        let params = IPerf3Protocol.parameterJSON(
            reverse: config.reverse, seconds: config.seconds, parallel: max(1, config.parallel)
        )
        guard let control, let message = IPerf3Protocol.encodeMessage(params) else {
            fail("Failed to encode parameters"); return
        }
        send(control, message)
    }

    // MARK: - Data streams

    private func openStreams() {
        guard let nwPort = NWEndpoint.Port(rawValue: config.port) else { return }
        for _ in 0..<max(1, config.parallel) {
            let stream = NWConnection(host: NWEndpoint.Host(config.host), port: nwPort, using: .tcp)
            stream.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                if case .ready = state {
                    self.send(stream, Data(self.cookie))
                    if self.config.reverse { self.receiveOnStream(stream) }
                } else if case .failed(let error) = state {
                    self.fail(error.localizedDescription)
                }
            }
            streams.append(stream)
            stream.start(queue: queue)
        }
    }

    private func beginTransfer() {
        guard startTime == nil else { return }   // TEST_RUNNING can repeat
        startTime = Date()
        // Emit a live throughput tick roughly twice a second.
        let ticker = DispatchSource.makeTimerSource(queue: queue)
        ticker.schedule(deadline: .now() + 0.5, repeating: 0.5)
        ticker.setEventHandler { [weak self] in
            guard let self, let start = self.startTime, !self.isDone else { return }
            let elapsed = Date().timeIntervalSince(start)
            self.emit(.running(
                mbps: IPerf3Protocol.megabitsPerSecond(bytes: self.transferred, seconds: elapsed),
                seconds: elapsed
            ))
        }
        ticker.resume()
        self.ticker = ticker

        if sending {
            // Client is the sender: blast blocks and run the test timer.
            streams.forEach { blast($0) }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + Double(config.seconds))
            timer.setEventHandler { [weak self] in
                guard let self, !self.isDone else { return }
                self.sendState(.testEnd)
                self.finishTransfer()
            }
            timer.resume()
            durationTimer = timer
        }
        // In reverse mode the server sends; our stream receive loops count bytes.
    }

    private func blast(_ stream: NWConnection) {
        guard !isDone, sending, startTime != nil else { return }
        stream.send(content: Data(block), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil { return }
            self.transferred += self.block.count
            self.blast(stream)   // keep the pipe full
        })
    }

    private func receiveOnStream(_ stream: NWConnection) {
        stream.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty { self.transferred += data.count }
            if error != nil || isComplete { return }
            if !self.isDone { self.receiveOnStream(stream) }
        }
    }

    private func finishTransfer() {
        durationTimer?.cancel(); durationTimer = nil
        ticker?.cancel(); ticker = nil
    }

    // MARK: - Results

    private func exchangeResults() {
        // Client sends its results first, then reads the server's.
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? Double(config.seconds)
        let results = IPerf3Protocol.resultsJSON(
            bytes: transferred, seconds: elapsed, streams: max(1, config.parallel)
        )
        guard let control, let message = IPerf3Protocol.encodeMessage(results) else {
            fail("Failed to encode results"); return
        }
        send(control, message)
        readServerResults()
    }

    /// Reads the server's 4-byte-prefixed results JSON, then acks with
    /// DISPLAY_RESULTS and resumes the control loop.
    private func readServerResults() {
        guard let control else { return }
        control.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error { self.fail(error.localizedDescription); return }
            guard let data, data.count == 4 else { self.fail("Truncated results header"); return }
            let length = IPerf3Protocol.decodeLength([UInt8](data))
            guard length > 0, length < 4_000_000 else { self.fail("Bad results length"); return }
            self.readServerResultsBody(remaining: length)
        }
    }

    private func readServerResultsBody(remaining: Int) {
        guard let control else { return }
        control.receive(minimumIncompleteLength: 1, maximumLength: remaining) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error { self.fail(error.localizedDescription); return }
            let got = data?.count ?? 0
            let left = remaining - got
            if left > 0 { self.readServerResultsBody(remaining: left); return }
            // Server results parsed only for completeness; local byte count drives display.
            self.sendState(.displayResults)
            self.readState()
        }
    }

    private func complete() {
        let elapsed = startTime.map { Date().timeIntervalSince($0) } ?? Double(config.seconds)
        let mbps = IPerf3Protocol.megabitsPerSecond(bytes: transferred, seconds: elapsed)
        emit(.finished(mbps: mbps, bytes: transferred, seconds: elapsed))
        teardown()
    }

    // MARK: - Helpers

    private func send(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func fail(_ message: String) {
        guard !isDone else { return }
        emit(.failed(message))
        teardown()
    }

    private func emit(_ event: Event) {
        onEvent?(event)
    }
}
