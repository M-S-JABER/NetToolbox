import Foundation
import Network

/// A minimal native MQTT 3.1.1 client over `Network.framework` (TCP or TLS),
/// zero dependencies. Supports CONNECT, SUBSCRIBE and PUBLISH at QoS 0 plus
/// keep-alive pings — enough to exercise a broker and watch live messages.
final class MQTTClient: @unchecked Sendable {
    enum Event: Sendable {
        case connected
        case subscribed
        case message(topic: String, payload: String)
        case disconnected(String?)
        case error(String)
    }

    private let host: String
    private let port: UInt16
    private let tls: Bool
    private let clientID: String
    private let username: String
    private let password: String
    private let keepAlive: UInt16 = 60

    private let queue = DispatchQueue(label: "com.nettoolbox.mqtt")
    private var connection: NWConnection?
    private var buffer = Data()
    private var packetID: UInt16 = 0
    private var pingTimer: DispatchSourceTimer?
    private var isStopped = false

    var onEvent: ((Event) -> Void)?

    init(host: String, port: UInt16, tls: Bool, clientID: String, username: String, password: String) {
        self.host = host
        self.port = port
        self.tls = tls
        self.clientID = clientID
        self.username = username
        self.password = password
    }

    // MARK: - Lifecycle

    func connect() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            onEvent?(.error("Invalid port"))
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: tls ? .tls : .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.receiveLoop()
                self.sendConnect()
            case .failed(let error), .waiting(let error):
                self.onEvent?(.error(error.localizedDescription))
            case .cancelled:
                if !self.isStopped { self.onEvent?(.disconnected(nil)) }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func subscribe(topic: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.packetID &+= 1
            var body: [UInt8] = [UInt8(self.packetID >> 8), UInt8(self.packetID & 0xFF)]
            body += MQTTClient.encodeString(topic)
            body += [0x00] // requested QoS 0
            self.write([0x82] + MQTTClient.encodeRemainingLength(body.count) + body)
        }
    }

    func publish(topic: String, message: String) {
        queue.async { [weak self] in
            guard let self else { return }
            var body = MQTTClient.encodeString(topic)
            body += [UInt8](message.utf8)
            self.write([0x30] + MQTTClient.encodeRemainingLength(body.count) + body)
        }
    }

    func disconnect() {
        queue.async { [weak self] in
            guard let self, !self.isStopped else { return }
            self.isStopped = true
            self.pingTimer?.cancel()
            self.pingTimer = nil
            self.write([0xE0, 0x00]) // DISCONNECT
            self.connection?.cancel()
            self.onEvent?(.disconnected(nil))
        }
    }

    // MARK: - Sending

    private func sendConnect() {
        var variable = MQTTClient.encodeString("MQTT") + [0x04] // protocol level 4 (3.1.1)
        var flags: UInt8 = 0x02 // clean session
        if !username.isEmpty { flags |= 0x80 }
        if !password.isEmpty { flags |= 0x40 }
        variable += [flags, UInt8(keepAlive >> 8), UInt8(keepAlive & 0xFF)]

        var payload = MQTTClient.encodeString(clientID)
        if !username.isEmpty { payload += MQTTClient.encodeString(username) }
        if !password.isEmpty { payload += MQTTClient.encodeString(password) }

        let body = variable + payload
        write([0x10] + MQTTClient.encodeRemainingLength(body.count) + body)
    }

    private func write(_ bytes: [UInt8]) {
        connection?.send(content: Data(bytes), completion: .contentProcessed { _ in })
    }

    private func startPing() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let interval = Int(keepAlive) - 5
        timer.schedule(deadline: .now() + .seconds(interval), repeating: .seconds(interval))
        timer.setEventHandler { [weak self] in
            guard let self, !self.isStopped else { return }
            self.write([0xC0, 0x00]) // PINGREQ
        }
        timer.resume()
        pingTimer = timer
    }

    // MARK: - Receiving

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.processBuffer()
            }
            if let error {
                self.onEvent?(.error(error.localizedDescription))
                return
            }
            if isComplete {
                if !self.isStopped { self.onEvent?(.disconnected(nil)) }
                return
            }
            self.receiveLoop()
        }
    }

    private func processBuffer() {
        while buffer.count >= 2 {
            guard let (remaining, lengthBytes) = MQTTClient.decodeRemainingLength(buffer, from: 1) else { return }
            let headerLength = 1 + lengthBytes
            let total = headerLength + remaining
            guard buffer.count >= total else { return }
            let packet = buffer.subdata(in: 0 ..< total)
            buffer.removeSubrange(0 ..< total)
            handlePacket(packet, headerLength: headerLength)
        }
    }

    private func handlePacket(_ packet: Data, headerLength: Int) {
        let bytes = [UInt8](packet)
        guard let first = bytes.first else { return }
        let type = first >> 4

        switch type {
        case 2: // CONNACK
            let returnCode = bytes.count >= 4 ? bytes[3] : 0xFF
            if returnCode == 0 {
                onEvent?(.connected)
                startPing()
            } else {
                onEvent?(.error("CONNECT refused (code \(returnCode))"))
            }
        case 9: // SUBACK
            onEvent?(.subscribed)
        case 3: // PUBLISH
            guard bytes.count >= headerLength + 2 else { return }
            let topicLength = Int(bytes[headerLength]) << 8 | Int(bytes[headerLength + 1])
            let topicStart = headerLength + 2
            guard bytes.count >= topicStart + topicLength else { return }
            let topic = String(decoding: bytes[topicStart ..< topicStart + topicLength], as: UTF8.self)
            var payloadStart = topicStart + topicLength
            let qos = (first >> 1) & 0x03
            if qos > 0 { payloadStart += 2 } // packet identifier present
            let payload = payloadStart <= bytes.count
                ? String(decoding: bytes[payloadStart...], as: UTF8.self)
                : ""
            onEvent?(.message(topic: topic, payload: payload))
        default:
            break // PINGRESP and others: ignore
        }
    }

    // MARK: - Wire helpers

    static func encodeString(_ string: String) -> [UInt8] {
        let bytes = [UInt8](string.utf8)
        return [UInt8(bytes.count >> 8), UInt8(bytes.count & 0xFF)] + bytes
    }

    static func encodeRemainingLength(_ length: Int) -> [UInt8] {
        var value = length
        var output: [UInt8] = []
        repeat {
            var byte = UInt8(value % 128)
            value /= 128
            if value > 0 { byte |= 0x80 }
            output.append(byte)
        } while value > 0
        return output
    }

    static func decodeRemainingLength(_ data: Data, from start: Int) -> (value: Int, bytes: Int)? {
        var multiplier = 1
        var value = 0
        var index = start
        var bytes = 0
        while true {
            guard index < data.count else { return nil }
            let byte = data[index]
            index += 1
            bytes += 1
            value += Int(byte & 0x7F) * multiplier
            if byte & 0x80 == 0 { break }
            multiplier *= 128
            if bytes >= 4 { break }
        }
        return (value, bytes)
    }
}
