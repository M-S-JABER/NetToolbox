import Foundation
import Network
import CoreMedia
import CryptoKit

/// A minimal, dependency-free RTSP-over-TCP client that drives a live H.264 /
/// H.265 stream into a `VideoDepacketizer`.
///
/// iOS has no RTSP support in AVFoundation, so the whole control channel is
/// spoken by hand over `Network.framework`: `DESCRIBE` → parse SDP → `SETUP`
/// (RTP interleaved on the same TCP connection) → `PLAY`, with Basic/Digest
/// authentication and periodic keep-alives. Media frames arrive interleaved
/// with `$`-framed binary packets, demuxed here and handed to the depacketizer.
final class RTSPClient: @unchecked Sendable {
    enum Status: Equatable {
        case connecting
        case buffering
        case playing
        case stopped
        case failed(String)
    }

    private let host: String
    private let port: UInt16
    private let username: String
    private let password: String
    private let baseURL: String

    private let queue = DispatchQueue(label: "com.nettoolbox.rtsp")
    private var connection: NWConnection?
    private var buffer = Data()
    private var cseq = 0
    private var sessionID: String?
    private var keepAliveSeconds = 50
    private var contentBase: String?
    private var videoChannel: UInt8 = 0
    private var depacketizer: VideoDepacketizer?
    private var keepAliveTimer: DispatchSourceTimer?
    private var isStopped = false

    // Auth challenge state.
    private var useBasic = false
    private var authRealm: String?
    private var authNonce: String?
    private var authQOP: String?

    private var responseWaiter: ((RTSPResponse?) -> Void)?

    var onStatus: ((Status) -> Void)?
    var onSample: ((CMSampleBuffer) -> Void)?

    init(host: String, port: UInt16, username: String, password: String, url: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.baseURL = url
    }

    // MARK: - Lifecycle

    func start() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            report(.failed("Invalid port"))
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.receiveLoop()
                Task { await self.runHandshake() }
            case .failed(let error):
                self.report(.failed(error.localizedDescription))
            case .waiting(let error):
                self.report(.failed(error.localizedDescription))
            case .cancelled:
                if !self.isStopped { self.report(.stopped) }
            default:
                break
            }
        }
        report(.connecting)
        connection.start(queue: queue)
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, !self.isStopped else { return }
            self.isStopped = true
            self.keepAliveTimer?.cancel()
            self.keepAliveTimer = nil
            if self.sessionID != nil {
                self.writeRequest("TEARDOWN", url: self.baseURL, headers: [:])
            }
            self.connection?.cancel()
            self.report(.stopped)
        }
    }

    // MARK: - Receive + demux

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            if let error {
                self.report(.failed(error.localizedDescription))
                return
            }
            if isComplete {
                if !self.isStopped { self.report(.stopped) }
                return
            }
            self.receiveLoop()
        }
    }

    private func processBuffer() {
        while let first = buffer.first {
            if first == 0x24 { // interleaved binary media frame
                guard buffer.count >= 4 else { return }
                let length = Int(buffer[2]) << 8 | Int(buffer[3])
                guard buffer.count >= 4 + length else { return }
                let channel = buffer[1]
                let packet = buffer.subdata(in: 4 ..< 4 + length)
                buffer.removeSubrange(0 ..< 4 + length)
                if channel == videoChannel { handleRTP(packet) }
            } else { // an RTSP text response
                guard let separator = buffer.range(of: Data([13, 10, 13, 10])) else { return }
                let headerString = String(decoding: buffer[0 ..< separator.lowerBound], as: UTF8.self)
                let contentLength = Self.contentLength(in: headerString)
                let bodyStart = separator.upperBound
                guard buffer.count >= bodyStart + contentLength else { return }
                let body = contentLength > 0
                    ? String(decoding: buffer[bodyStart ..< bodyStart + contentLength], as: UTF8.self)
                    : ""
                buffer.removeSubrange(0 ..< bodyStart + contentLength)
                let waiter = responseWaiter
                responseWaiter = nil
                waiter?(RTSPResponse(headerString: headerString, body: body))
            }
        }
    }

    private func handleRTP(_ packet: Data) {
        let bytes = [UInt8](packet)
        guard bytes.count >= 12 else { return }
        let csrcCount = Int(bytes[0] & 0x0F)
        let hasExtension = (bytes[0] & 0x10) != 0
        let marker = (bytes[1] & 0x80) != 0
        let timestamp = UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8 | UInt32(bytes[7])

        var headerLength = 12 + csrcCount * 4
        if hasExtension {
            guard bytes.count >= headerLength + 4 else { return }
            let extWords = Int(bytes[headerLength + 2]) << 8 | Int(bytes[headerLength + 3])
            headerLength += 4 + extWords * 4
        }
        guard bytes.count > headerLength else { return }
        let payload = Data(bytes[headerLength...])
        depacketizer?.handle(payload: payload, marker: marker, timestamp: timestamp)
    }

    // MARK: - Handshake

    private func runHandshake() async {
        // DESCRIBE (retry once with credentials if challenged).
        var response = await sendRequest("DESCRIBE", url: baseURL, headers: ["Accept": "application/sdp"])
        if response?.status == 401 {
            parseAuthChallenge(response?.headers["www-authenticate"])
            response = await sendRequest("DESCRIBE", url: baseURL, headers: ["Accept": "application/sdp"])
        }
        guard let describe = response else { failIfRunning("No response from camera"); return }
        guard describe.status != 401 else { failIfRunning("Authentication failed — check the username and password"); return }
        guard describe.status == 200 else { failIfRunning("DESCRIBE failed (\(describe.status))"); return }

        contentBase = describe.headers["content-base"] ?? baseURL
        guard let media = SDPParser.parseVideo(describe.body) else {
            failIfRunning("No supported H.264/H.265 video track found")
            return
        }

        // SETUP the video track with interleaved TCP transport.
        let trackURL = resolveControlURL(media.control)
        var setupResponse = await sendRequest("SETUP", url: trackURL, headers: [
            "Transport": "RTP/AVP/TCP;unicast;interleaved=0-1"
        ])
        if setupResponse?.status == 401 {
            parseAuthChallenge(setupResponse?.headers["www-authenticate"])
            setupResponse = await sendRequest("SETUP", url: trackURL, headers: [
                "Transport": "RTP/AVP/TCP;unicast;interleaved=0-1"
            ])
        }
        guard let setup = setupResponse, setup.status == 200 else {
            failIfRunning("SETUP failed (\(setupResponse?.status ?? 0))")
            return
        }
        if let session = setup.headers["session"] {
            sessionID = session.split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespaces) }
            if let timeoutValue = Self.param(in: session, key: "timeout"), let seconds = Int(timeoutValue) {
                keepAliveSeconds = max(15, seconds - 5)
            }
        }
        if let transport = setup.headers["transport"], let channel = Self.interleavedChannel(in: transport) {
            videoChannel = channel
        }

        let depack = VideoDepacketizer(codec: media.codec, clockRate: media.clockRate) { [weak self] sample in
            self?.onSample?(sample)
        }
        depack.seedParameterSets(media.parameterSets)
        depacketizer = depack

        // PLAY.
        let playResponse = await sendRequest("PLAY", url: baseURL, headers: ["Range": "npt=0.000-"])
        guard let play = playResponse, play.status == 200 else {
            failIfRunning("PLAY failed (\(playResponse?.status ?? 0))")
            return
        }
        report(.playing)
        startKeepAlive()
    }

    // MARK: - Request/response

    private func sendRequest(_ method: String, url: String, headers: [String: String]) async -> RTSPResponse? {
        await withCheckedContinuation { continuation in
            queue.async {
                if self.isStopped { continuation.resume(returning: nil); return }
                var resumed = false
                let finish: (RTSPResponse?) -> Void = { response in
                    guard !resumed else { return }
                    resumed = true
                    self.responseWaiter = nil
                    continuation.resume(returning: response)
                }
                self.responseWaiter = { finish($0) }
                self.writeRequest(method, url: url, headers: headers)
                // Fire the timeout through the stored waiter (which itself calls
                // `finish`) so this @Sendable closure captures only `self`, not
                // the non-Sendable `finish` closure.
                self.queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.responseWaiter?(nil)
                }
            }
        }
    }

    private func writeRequest(_ method: String, url: String, headers: [String: String]) {
        cseq += 1
        var lines = ["\(method) \(url) RTSP/1.0", "CSeq: \(cseq)", "User-Agent: NetToolbox"]
        if let sessionID { lines.append("Session: \(sessionID)") }
        if let authorization = authHeader(method: method, uri: url) { lines.append("Authorization: \(authorization)") }
        for (key, value) in headers { lines.append("\(key): \(value)") }
        let request = lines.joined(separator: "\r\n") + "\r\n\r\n"
        connection?.send(content: Data(request.utf8), completion: .contentProcessed { _ in })
    }

    private func startKeepAlive() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(keepAliveSeconds), repeating: .seconds(keepAliveSeconds))
        timer.setEventHandler { [weak self] in
            guard let self, !self.isStopped else { return }
            // Fire-and-forget keep-alive; the reply is ignored by processBuffer.
            self.writeRequest("GET_PARAMETER", url: self.baseURL, headers: [:])
        }
        timer.resume()
        keepAliveTimer = timer
    }

    // MARK: - Auth

    private func authHeader(method: String, uri: String) -> String? {
        guard !username.isEmpty || !password.isEmpty else { return nil }
        if useBasic {
            let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
            return "Basic \(credentials)"
        }
        guard let nonce = authNonce, let realm = authRealm else { return nil }
        let ha1 = Self.md5("\(username):\(realm):\(password)")
        let ha2 = Self.md5("\(method):\(uri)")
        if let qop = authQOP, qop.contains("auth") {
            let nc = "00000001"
            let cnonce = String(format: "%08x", UInt32.random(in: 0 ... UInt32.max))
            let response = Self.md5("\(ha1):\(nonce):\(nc):\(cnonce):auth:\(ha2)")
            return "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\", algorithm=MD5, qop=auth, nc=\(nc), cnonce=\"\(cnonce)\""
        }
        let response = Self.md5("\(ha1):\(nonce):\(ha2)")
        return "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\", algorithm=MD5"
    }

    private func parseAuthChallenge(_ value: String?) {
        guard let value else { return }
        if value.lowercased().hasPrefix("basic") {
            useBasic = true
            authRealm = Self.param(in: value, key: "realm")
            return
        }
        useBasic = false
        authRealm = Self.param(in: value, key: "realm")
        authNonce = Self.param(in: value, key: "nonce")
        authQOP = Self.param(in: value, key: "qop")
    }

    // MARK: - Helpers

    private func resolveControlURL(_ control: String) -> String {
        if control.isEmpty || control == "*" { return baseURL }
        if control.lowercased().hasPrefix("rtsp://") { return control }
        let base = contentBase ?? baseURL
        return base.hasSuffix("/") ? base + control : base + "/" + control
    }

    private func report(_ status: Status) {
        onStatus?(status)
    }

    private func failIfRunning(_ message: String) {
        guard !isStopped else { return }
        report(.failed(message))
    }

    private static func md5(_ string: String) -> String {
        Insecure.MD5.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func contentLength(in header: String) -> Int {
        for line in header.components(separatedBy: "\r\n") where line.lowercased().hasPrefix("content-length:") {
            return Int(line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
        }
        return 0
    }

    /// Reads `key="value"` or `key=value` from a header parameter list.
    private static func param(in source: String, key: String) -> String? {
        guard let keyRange = source.range(of: "\(key)=", options: .caseInsensitive) else { return nil }
        var rest = source[keyRange.upperBound...]
        if rest.first == "\"" {
            rest = rest.dropFirst()
            guard let end = rest.firstIndex(of: "\"") else { return nil }
            return String(rest[..<end])
        }
        let end = rest.firstIndex(where: { $0 == "," || $0 == " " || $0 == ";" }) ?? rest.endIndex
        return String(rest[..<end])
    }

    private static func interleavedChannel(in transport: String) -> UInt8? {
        guard let value = param(in: transport, key: "interleaved") else { return nil }
        let first = value.split(separator: "-").first.map(String.init) ?? value
        return UInt8(first)
    }
}

/// A parsed RTSP status line + headers (lowercased keys) + body.
struct RTSPResponse {
    let status: Int
    let headers: [String: String]
    let body: String

    init(headerString: String, body: String) {
        let lines = headerString.components(separatedBy: "\r\n")
        var code = 0
        if let statusLine = lines.first {
            let parts = statusLine.split(separator: " ")
            if parts.count >= 2 { code = Int(parts[1]) ?? 0 }
        }
        var map: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            map[key] = value
        }
        self.status = code
        self.headers = map
        self.body = body
    }
}
