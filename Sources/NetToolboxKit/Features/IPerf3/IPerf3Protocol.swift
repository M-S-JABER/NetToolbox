import Foundation

/// Pure, dependency-free pieces of the iperf3 control protocol (RFC-less;
/// mirrors iperf 3.x `src/iperf_api.h`). Framing, the cookie, the parameter
/// JSON and throughput maths live here so they can be unit-tested; the live
/// socket state machine is in `IPerf3Client`.
enum IPerf3Protocol {

    /// Single-byte control-channel states exchanged over the TCP connection.
    enum State: UInt8 {
        case testStart = 1
        case testRunning = 2
        case testEnd = 4
        case paramExchange = 9
        case createStreams = 10
        case serverTerminate = 11
        case clientTerminate = 12
        case exchangeResults = 13
        case displayResults = 14
        case iperfStart = 15
        case iperfDone = 16
        case accessDenied = 0xFF   // -1
        case serverError = 0xFE    // -2
    }

    static let controlPort: UInt16 = 5201
    static let cookieSize = 37
    /// Default TCP block size iperf3 uses (128 KiB).
    static let blockSize = 131_072
    private static let cookieAlphabet = Array("abcdefghijklmnopqrstuvwxyz234567".utf8)

    /// Builds a 37-byte cookie: 36 characters from the base32 alphabet plus a
    /// trailing NUL, matching iperf3's `make_cookie`. `bytePicker` supplies the
    /// randomness (injected so tests are deterministic).
    static func makeCookie(_ bytePicker: () -> UInt8) -> [UInt8] {
        var cookie = [UInt8](repeating: 0, count: cookieSize)
        for index in 0..<(cookieSize - 1) {
            cookie[index] = cookieAlphabet[Int(bytePicker()) % cookieAlphabet.count]
        }
        cookie[cookieSize - 1] = 0
        return cookie
    }

    /// A random cookie for live runs.
    static func randomCookie() -> [UInt8] {
        makeCookie { UInt8.random(in: 0...255) }
    }

    /// The test-parameter JSON the client sends on PARAM_EXCHANGE.
    static func parameterJSON(
        reverse: Bool, seconds: Int, parallel: Int,
        blockLength: Int = blockSize, clientVersion: String = "3.16"
    ) -> [String: Any] {
        [
            "tcp": true,
            "omit": 0,
            "time": seconds,
            "num": 0,
            "blockcount": 0,
            "parallel": parallel,
            "reverse": reverse,
            "len": blockLength,
            "pacing_timer": 1000,
            "client_version": clientVersion
        ]
    }

    /// Serializes a control message as a 4-byte big-endian length prefix
    /// followed by the JSON body.
    static func encodeMessage(_ object: [String: Any]) -> Data? {
        guard let body = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return lengthPrefixed(body)
    }

    /// Prepends the 4-byte big-endian length used by param/results messages.
    static func lengthPrefixed(_ body: Data) -> Data {
        let length = UInt32(body.count)
        var prefix = Data(count: 4)
        prefix[0] = UInt8((length >> 24) & 0xFF)
        prefix[1] = UInt8((length >> 16) & 0xFF)
        prefix[2] = UInt8((length >> 8) & 0xFF)
        prefix[3] = UInt8(length & 0xFF)
        return prefix + body
    }

    /// Reads a 4-byte big-endian length.
    static func decodeLength(_ bytes: [UInt8]) -> Int {
        guard bytes.count >= 4 else { return 0 }
        return (Int(bytes[0]) << 24) | (Int(bytes[1]) << 16) | (Int(bytes[2]) << 8) | Int(bytes[3])
    }

    /// The results JSON the client returns on EXCHANGE_RESULTS. iperf3 accepts a
    /// minimal object; the server computes its own authoritative figures.
    static func resultsJSON(bytes: Int, seconds: Double, streams: Int) -> [String: Any] {
        let perStream = max(1, streams)
        let streamObjects = (0..<perStream).map { _ in
            [
                "id": 1,
                "bytes": bytes / perStream,
                "retransmits": -1,
                "jitter": 0,
                "errors": 0,
                "packets": 0,
                "start_time": 0,
                "end_time": seconds
            ] as [String: Any]
        }
        return ["cpu_util_total": 0, "cpu_util_user": 0, "cpu_util_system": 0,
                "sender_has_retransmits": -1, "streams": streamObjects]
    }

    /// Throughput in megabits per second from bytes transferred over a window.
    static func megabitsPerSecond(bytes: Int, seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        return (Double(bytes) * 8) / seconds / 1_000_000
    }
}
