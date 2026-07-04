import Foundation
import CryptoKit

/// Outcome of a one-shot SSH exec session.
struct SSHRunResult: Sendable {
    var output: String
    var fingerprint: String
    var hostKeyType: String
    var hostKeyVerified: Bool
    var exitStatus: Int?
}

enum SSHError: LocalizedError {
    case transport(String)
    case disconnected
    case disconnectedByServer(String)
    case unsupportedServer(String)
    case noCipher
    case kexFailed
    case authFailed
    case channelFailed
    case protocolError
    case encryptFailed
    case decryptFailed(verified: Bool)

    var errorDescription: String? {
        switch self {
        case .transport(let m): return m
        case .disconnected: return L10nString("ssh.error.disconnected")
        case .disconnectedByServer(let m):
            return L10nString("ssh.error.serverClosed") + (m.isEmpty ? "" : ": \(m)")
        case .unsupportedServer(let v):
            return L10nString("ssh.error.unsupported") + " \(v)"
        case .noCipher: return L10nString("ssh.error.noCipher")
        case .kexFailed: return L10nString("ssh.error.kex")
        case .authFailed: return L10nString("ssh.error.auth")
        case .channelFailed: return L10nString("ssh.error.channel")
        case .protocolError: return L10nString("ssh.error.protocol")
        case .encryptFailed: return L10nString("ssh.error.encrypt")
        case .decryptFailed(let verified):
            return L10nString("ssh.error.decrypt")
                + " " + L10nString(verified ? "ssh.error.decrypt.hintVerified" : "ssh.error.decrypt.hintUnverified")
        }
    }
}

/// A minimal SSH-2 client that opens a session, runs one command, and
/// returns its output. Key exchange `curve25519-sha256`, cipher
/// `aes256-gcm@openssh.com`, password auth — all on CryptoKit/Security so
/// the package keeps zero external dependencies.
final class SSHClient: @unchecked Sendable {
    private enum Msg {
        static let disconnect: UInt8 = 1
        static let ignore: UInt8 = 2
        static let debug: UInt8 = 4
        static let serviceRequest: UInt8 = 5
        static let serviceAccept: UInt8 = 6
        static let kexInit: UInt8 = 20
        static let newKeys: UInt8 = 21
        static let kexECDHInit: UInt8 = 30
        static let kexECDHReply: UInt8 = 31
        static let userauthRequest: UInt8 = 50
        static let userauthFailure: UInt8 = 51
        static let userauthSuccess: UInt8 = 52
        static let userauthBanner: UInt8 = 53
        static let globalRequest: UInt8 = 80
        static let requestFailure: UInt8 = 82
        static let channelOpen: UInt8 = 90
        static let channelOpenConfirm: UInt8 = 91
        static let channelWindowAdjust: UInt8 = 93
        static let channelData: UInt8 = 94
        static let channelExtData: UInt8 = 95
        static let channelEOF: UInt8 = 96
        static let channelClose: UInt8 = 97
        static let channelRequest: UInt8 = 98
    }

    private let connection: TCPConnection
    private var inbound: [UInt8] = []
    private var encrypt: SSHGCMCipher?
    private var decrypt: SSHGCMCipher?
    /// Whether the server's host-key signature over the exchange hash checked
    /// out — surfaced in a decryption failure to tell "wrong exchange hash"
    /// (unverified) apart from "wrong key derivation" (verified) when
    /// diagnosing interop issues.
    private var hostKeyVerified = false

    /// A one-line diagnostic (host-key type, verified flag, fingerprint,
    /// stage) filled in as the handshake proceeds, so a single screenshot of
    /// a failure is enough to pinpoint the cause.
    private(set) var diagnostics = ""
    private(set) var stage = "connect"

    init?(host: String, port: UInt16) {
        guard let connection = TCPConnection(host: host, port: port) else { return nil }
        self.connection = connection
    }

    func run(username: String, password: String, command: String, timeout: Double) async throws -> SSHRunResult {
        switch await connection.open(timeout: timeout) {
        case .success: break
        case .failure(let error): throw SSHError.transport(error.localizedDescription)
        }
        defer { connection.cancel() }

        // 1) Version exchange.
        let clientVersion = "SSH-2.0-NetToolbox_1.0"
        try await writeRaw(Data((clientVersion + "\r\n").utf8))
        var serverVersion = ""
        for _ in 0..<64 {
            let line = try await readLine()
            if line.hasPrefix("SSH-") { serverVersion = line; break }
        }
        guard serverVersion.hasPrefix("SSH-2.0") || serverVersion.hasPrefix("SSH-1.99") else {
            throw SSHError.unsupportedServer(serverVersion)
        }

        // 2) Algorithm negotiation.
        let clientKexInit = buildKexInit()
        try await sendPacket(clientKexInit)
        let serverKexInit = try await expect(Msg.kexInit)
        try requireCiphers(in: serverKexInit)

        // 3) Curve25519 ECDH.
        let priv = Curve25519.KeyAgreement.PrivateKey()
        let qc = priv.publicKey.rawRepresentation
        var initPayload = Data([Msg.kexECDHInit])
        SSHWire.putString(qc, into: &initPayload)
        try await sendPacket(initPayload)

        let reply = try await expect(Msg.kexECDHReply)
        var replyReader = SSHWire.Reader(reply)
        _ = replyReader.readByte()
        guard let hostKey = replyReader.readString(),
              let qs = replyReader.readString(),
              let signature = replyReader.readString(),
              let serverPub = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: qs),
              let shared = try? priv.sharedSecretFromKeyAgreement(with: serverPub) else {
            throw SSHError.kexFailed
        }

        let sharedBytes = shared.withUnsafeBytes { Data($0) }
        let kMPInt = SSHCrypto.mpint(sharedBytes)
        let exchangeHash = SSHCrypto.exchangeHash(
            clientVersion: clientVersion, serverVersion: serverVersion,
            clientKexInit: clientKexInit, serverKexInit: serverKexInit,
            hostKey: hostKey, clientEphemeral: qc, serverEphemeral: qs,
            sharedSecretMPInt: kMPInt
        )
        let verified = SSHCrypto.verifyHostKey(blob: hostKey, signature: signature, over: exchangeHash)
        hostKeyVerified = verified

        var keyTypeReader = SSHWire.Reader(hostKey)
        let hostKeyType = keyTypeReader.readStringUTF8() ?? "?"
        let fingerprint = "SHA256:" + Data(SHA256.hash(data: hostKey)).base64EncodedString()
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        diagnostics = "SSHv2 · host=\(hostKeyType) · verified=\(verified) · \(fingerprint)"

        // 4) Activate keys.
        stage = "newkeys"
        let sessionID = exchangeHash
        let ivC2S = SSHCrypto.deriveKey(letter: 0x41, length: 12, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)
        let ivS2C = SSHCrypto.deriveKey(letter: 0x42, length: 12, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)
        let keyC2S = SSHCrypto.deriveKey(letter: 0x43, length: 32, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)
        let keyS2C = SSHCrypto.deriveKey(letter: 0x44, length: 32, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)

        try await sendPacket(Data([Msg.newKeys]))
        _ = try await expect(Msg.newKeys)
        encrypt = SSHGCMCipher(key: keyC2S, iv: ivC2S)
        decrypt = SSHGCMCipher(key: keyS2C, iv: ivS2C)

        // 5) Authenticate with a password.
        stage = "service-request"
        var serviceRequest = Data([Msg.serviceRequest])
        SSHWire.putString("ssh-userauth", into: &serviceRequest)
        try await sendPacket(serviceRequest)
        _ = try await expect(Msg.serviceAccept)
        stage = "userauth"

        var authRequest = Data([Msg.userauthRequest])
        SSHWire.putString(username, into: &authRequest)
        SSHWire.putString("ssh-connection", into: &authRequest)
        SSHWire.putString("password", into: &authRequest)
        authRequest.append(0)                          // FALSE: not changing the password
        SSHWire.putString(password, into: &authRequest)
        try await sendPacket(authRequest)

        authLoop: while true {
            let payload = try await nextPayload()
            switch payload.first {
            case Msg.userauthSuccess: break authLoop
            case Msg.userauthBanner: continue
            case Msg.userauthFailure: throw SSHError.authFailed
            default: throw SSHError.protocolError
            }
        }

        // 6) Open a session channel and exec the command.
        stage = "channel"
        let localChannel: UInt32 = 0
        var open = Data([Msg.channelOpen])
        SSHWire.putString("session", into: &open)
        SSHWire.putUInt32(localChannel, into: &open)
        SSHWire.putUInt32(1_048_576, into: &open)      // initial window
        SSHWire.putUInt32(32_768, into: &open)         // max packet
        try await sendPacket(open)

        let confirm = try await expect(Msg.channelOpenConfirm)
        var confirmReader = SSHWire.Reader(confirm)
        _ = confirmReader.readByte()
        _ = confirmReader.readUInt32()                 // our channel
        guard let remoteChannel = confirmReader.readUInt32() else { throw SSHError.channelFailed }

        var exec = Data([Msg.channelRequest])
        SSHWire.putUInt32(remoteChannel, into: &exec)
        SSHWire.putString("exec", into: &exec)
        exec.append(1)                                 // want_reply
        SSHWire.putString(command, into: &exec)
        try await sendPacket(exec)

        // 7) Collect output until the channel closes.
        stage = "exec"
        var output = Data()
        var exitStatus: Int?
        var sinceAdjust = 0

        readLoop: while output.count < 4_000_000 {
            let payload = try await nextPayload()
            guard let code = payload.first else { continue }
            var reader = SSHWire.Reader(payload)
            _ = reader.readByte()

            switch code {
            case Msg.channelData:
                _ = reader.readUInt32()
                if let chunk = reader.readString() {
                    output.append(chunk)
                    sinceAdjust += chunk.count
                }
            case Msg.channelExtData:
                _ = reader.readUInt32()
                _ = reader.readUInt32()                // data type (stderr)
                if let chunk = reader.readString() { output.append(chunk) }
            case Msg.channelRequest:
                _ = reader.readUInt32()
                let requestType = reader.readStringUTF8()
                _ = reader.readByte()                  // want_reply
                if requestType == "exit-status" { exitStatus = reader.readUInt32().map(Int.init) }
            case Msg.channelEOF, Msg.channelWindowAdjust:
                break
            case Msg.channelClose:
                var close = Data([Msg.channelClose])
                SSHWire.putUInt32(remoteChannel, into: &close)
                try? await sendPacket(close)
                break readLoop
            default:
                break
            }

            // Replenish the flow-control window for long output.
            if sinceAdjust >= 524_288 {
                var adjust = Data([Msg.channelWindowAdjust])
                SSHWire.putUInt32(remoteChannel, into: &adjust)
                SSHWire.putUInt32(UInt32(sinceAdjust), into: &adjust)
                try await sendPacket(adjust)
                sinceAdjust = 0
            }
        }

        return SSHRunResult(
            output: String(decoding: output, as: UTF8.self),
            fingerprint: fingerprint,
            hostKeyType: hostKeyType,
            hostKeyVerified: verified,
            exitStatus: exitStatus
        )
    }

    // MARK: - KEXINIT

    private func buildKexInit() -> Data {
        var payload = Data([Msg.kexInit])
        payload.append(Data((0..<16).map { _ in UInt8.random(in: 0...255) }))   // cookie
        SSHWire.putNameList(["curve25519-sha256", "curve25519-sha256@libssh.org"], into: &payload)
        SSHWire.putNameList(["ssh-ed25519", "ecdsa-sha2-nistp256", "rsa-sha2-512", "rsa-sha2-256"], into: &payload)
        SSHWire.putNameList(["aes256-gcm@openssh.com", "aes128-gcm@openssh.com"], into: &payload)   // c2s
        SSHWire.putNameList(["aes256-gcm@openssh.com", "aes128-gcm@openssh.com"], into: &payload)   // s2c
        SSHWire.putNameList(["hmac-sha2-256", "hmac-sha2-512"], into: &payload)   // c2s (unused with GCM)
        SSHWire.putNameList(["hmac-sha2-256", "hmac-sha2-512"], into: &payload)   // s2c
        SSHWire.putNameList(["none"], into: &payload)     // compression c2s
        SSHWire.putNameList(["none"], into: &payload)     // compression s2c
        SSHWire.putNameList([], into: &payload)           // languages c2s
        SSHWire.putNameList([], into: &payload)           // languages s2c
        payload.append(0)                                 // first_kex_packet_follows
        SSHWire.putUInt32(0, into: &payload)              // reserved
        return payload
    }

    /// Confirms the server offers curve25519 key exchange and our GCM cipher
    /// in both directions — the only combination this client implements.
    private func requireCiphers(in kexInit: Data) throws {
        var reader = SSHWire.Reader(kexInit)
        _ = reader.readByte()
        for _ in 0..<16 { _ = reader.readByte() }         // cookie
        guard let kex = reader.readNameList() else { throw SSHError.kexFailed }
        _ = reader.readNameList()                          // host keys
        guard let c2s = reader.readNameList(), let s2c = reader.readNameList() else { throw SSHError.kexFailed }
        let curve = kex.contains("curve25519-sha256") || kex.contains("curve25519-sha256@libssh.org")
        guard curve else { throw SSHError.noCipher }
        let ours = "aes256-gcm@openssh.com"
        guard c2s.contains(ours), s2c.contains(ours) else { throw SSHError.noCipher }
    }

    // MARK: - Packet framing

    private func sendPacket(_ payload: Data) async throws {
        if var cipher = encrypt {
            var pad = 16 - ((1 + payload.count) % 16)
            if pad < 4 { pad += 16 }
            var lengthField = Data()
            SSHWire.putUInt32(UInt32(1 + payload.count + pad), into: &lengthField)
            let plaintext = Data([UInt8(pad)]) + payload + randomBytes(pad)
            guard let sealed = cipher.seal(plaintext: plaintext, lengthField: lengthField) else { throw SSHError.encryptFailed }
            encrypt = cipher
            try await writeRaw(lengthField + sealed)
        } else {
            var pad = 8 - ((4 + 1 + payload.count) % 8)
            if pad < 4 { pad += 8 }
            var packet = Data()
            SSHWire.putUInt32(UInt32(1 + payload.count + pad), into: &packet)
            packet.append(UInt8(pad))
            packet.append(payload)
            packet.append(randomBytes(pad))
            try await writeRaw(packet)
        }
    }

    private func receivePacket() async throws -> Data {
        let lengthField = try await readExact(4)
        let packetLength = Int(lengthField.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
        guard packetLength > 0, packetLength <= 1_048_576 else { throw SSHError.protocolError }

        if var cipher = decrypt {
            let body = try await readExact(packetLength + 16)
            let ciphertext = Data(body.prefix(packetLength))
            let tag = Data(body.suffix(16))
            guard let plaintext = cipher.open(ciphertext: ciphertext, tag: tag, lengthField: lengthField) else {
                throw SSHError.decryptFailed(verified: hostKeyVerified)
            }
            decrypt = cipher
            return extractPayload(plaintext, packetLength: plaintext.count)
        } else {
            let rest = try await readExact(packetLength)
            return extractPayload(rest, packetLength: packetLength)
        }
    }

    /// Strips `padding_length` and the trailing padding from a packet body.
    private func extractPayload(_ body: Data, packetLength: Int) -> Data {
        let padLength = Int(body.first ?? 0)
        let payloadCount = packetLength - 1 - padLength
        guard payloadCount >= 0, body.count >= 1 + payloadCount else { return Data() }
        return Data(body.dropFirst().prefix(payloadCount))
    }

    /// Reads the next real payload, transparently handling transport-level
    /// housekeeping messages and turning DISCONNECT into an error.
    private func nextPayload() async throws -> Data {
        while true {
            let payload = try await receivePacket()
            guard let code = payload.first else { continue }
            switch code {
            case Msg.disconnect:
                var reader = SSHWire.Reader(payload)
                _ = reader.readByte()
                _ = reader.readUInt32()
                throw SSHError.disconnectedByServer(reader.readStringUTF8() ?? "")
            case Msg.ignore, Msg.debug:
                continue
            case Msg.globalRequest:
                var reader = SSHWire.Reader(payload)
                _ = reader.readByte()
                _ = reader.readStringUTF8()
                let wantReply = (reader.readByte() ?? 0) != 0
                if wantReply { try await sendPacket(Data([Msg.requestFailure])) }
                continue
            default:
                return payload
            }
        }
    }

    private func expect(_ code: UInt8) async throws -> Data {
        let payload = try await nextPayload()
        guard payload.first == code else { throw SSHError.protocolError }
        return payload
    }

    // MARK: - Raw byte I/O

    private func randomBytes(_ count: Int) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: 0...255) })
    }

    private func writeRaw(_ data: Data) async throws {
        if case .failure(let error) = await connection.send(data) {
            throw SSHError.transport(error.localizedDescription)
        }
    }

    private func fill() async throws {
        switch await connection.receive() {
        case .success(let data):
            if data.isEmpty { throw SSHError.disconnected }
            inbound.append(contentsOf: data)
        case .failure(let error):
            throw SSHError.transport(error.localizedDescription)
        }
    }

    private func readExact(_ count: Int) async throws -> Data {
        while inbound.count < count { try await fill() }
        let head = Data(inbound[0..<count])
        inbound.removeFirst(count)
        return head
    }

    private func readLine() async throws -> String {
        while true {
            if let newline = inbound.firstIndex(of: 0x0A) {
                let line = Array(inbound[0...newline])
                inbound.removeFirst(newline + 1)
                var text = String(decoding: line, as: UTF8.self)
                while text.hasSuffix("\n") || text.hasSuffix("\r") { text.removeLast() }
                return text
            }
            try await fill()
        }
    }
}
