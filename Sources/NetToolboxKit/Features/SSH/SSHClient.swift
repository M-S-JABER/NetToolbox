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

/// How to authenticate an SSH session.
enum SSHAuth: Sendable {
    case password(String)
    case key(SSHPrivateKey)
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

/// A minimal SSH-2 client (curve25519-sha256 + aes256-gcm@openssh.com,
/// password or ed25519 public-key auth), built entirely on CryptoKit/Security
/// so the package keeps zero external dependencies. Supports one-shot exec,
/// SFTP directory listing / download, and a line-oriented interactive shell.
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
        static let channelSuccess: UInt8 = 99
        static let channelFailure: UInt8 = 100
    }

    private let connection: TCPConnection
    private var inbound: [UInt8] = []
    private var encrypt: SSHGCMCipher?
    private var decrypt: SSHGCMCipher?
    private var hostKeyVerified = false

    private(set) var diagnostics = ""
    private(set) var stage = "connect"
    private(set) var fingerprint = ""
    private(set) var hostKeyTypeName = "?"
    private var sessionID = Data()
    /// Buffer for reassembling SFTP packets carried inside channel data.
    private var sftpBuffer: [UInt8] = []
    private var shellChannel: UInt32?

    init?(host: String, port: UInt16) {
        guard let connection = TCPConnection(host: host, port: port) else { return nil }
        self.connection = connection
    }

    func close() { connection.cancel() }

    // MARK: - Handshake (shared by exec, SFTP and shell)

    /// Runs the full transport handshake and user authentication, leaving the
    /// GCM ciphers active and the session ready for channel operations. Does
    /// NOT close the connection — callers own the lifecycle.
    private func establish(username: String, auth: SSHAuth, timeout: Double) async throws {
        switch await connection.open(timeout: timeout) {
        case .success: break
        case .failure(let error): throw SSHError.transport(error.localizedDescription)
        }

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

        let clientKexInit = buildKexInit()
        try await sendPacket(clientKexInit)
        let serverKexInit = try await expect(Msg.kexInit)
        try requireCiphers(in: serverKexInit)

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
        hostKeyVerified = SSHCrypto.verifyHostKey(blob: hostKey, signature: signature, over: exchangeHash)

        var keyTypeReader = SSHWire.Reader(hostKey)
        hostKeyTypeName = keyTypeReader.readStringUTF8() ?? "?"
        fingerprint = "SHA256:" + Data(SHA256.hash(data: hostKey)).base64EncodedString()
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let hHex = exchangeHash.prefix(6).map { String(format: "%02x", $0) }.joined()
        diagnostics = "SSHv2 host=\(hostKeyTypeName) verified=\(hostKeyVerified) vs=[\(serverVersion)] "
            + "ic=\(clientKexInit.count) is=\(serverKexInit.count) ks=\(hostKey.count) "
            + "qc=\(qc.count) qs=\(qs.count) K=\(sharedBytes.count) H=\(hHex)"

        stage = "newkeys"
        sessionID = exchangeHash
        let ivC2S = SSHCrypto.deriveKey(letter: 0x41, length: 12, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)
        let ivS2C = SSHCrypto.deriveKey(letter: 0x42, length: 12, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)
        let keyC2S = SSHCrypto.deriveKey(letter: 0x43, length: 32, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)
        let keyS2C = SSHCrypto.deriveKey(letter: 0x44, length: 32, sharedSecretMPInt: kMPInt, exchangeHash: exchangeHash, sessionID: sessionID)

        try await sendPacket(Data([Msg.newKeys]))
        _ = try await expect(Msg.newKeys)
        encrypt = SSHGCMCipher(key: keyC2S, iv: ivC2S)
        decrypt = SSHGCMCipher(key: keyS2C, iv: ivS2C)

        stage = "service-request"
        var serviceRequest = Data([Msg.serviceRequest])
        SSHWire.putString("ssh-userauth", into: &serviceRequest)
        try await sendPacket(serviceRequest)
        _ = try await expect(Msg.serviceAccept)
        stage = "userauth"
        try await authenticate(username: username, auth: auth)
    }

    /// Password or ed25519 public-key user authentication.
    private func authenticate(username: String, auth: SSHAuth) async throws {
        var request = Data([Msg.userauthRequest])
        SSHWire.putString(username, into: &request)
        SSHWire.putString("ssh-connection", into: &request)
        switch auth {
        case .password(let password):
            SSHWire.putString("password", into: &request)
            request.append(0)                          // not changing the password
            SSHWire.putString(password, into: &request)
        case .key(let key):
            SSHWire.putString("publickey", into: &request)
            request.append(1)                          // with signature
            SSHWire.putString("ssh-ed25519", into: &request)
            SSHWire.putString(key.publicKeyBlob, into: &request)
            // Sign string(session_id) || (the request built so far).
            var signed = Data()
            SSHWire.putString(sessionID, into: &signed)
            signed.append(request)
            let signature = try key.sign(signed)
            var signatureBlob = Data()
            SSHWire.putString("ssh-ed25519", into: &signatureBlob)
            SSHWire.putString(signature, into: &signatureBlob)
            SSHWire.putString(signatureBlob, into: &request)
        }
        try await sendPacket(request)

        while true {
            let payload = try await nextPayload()
            switch payload.first {
            case Msg.userauthSuccess: return
            case Msg.userauthBanner: continue
            case Msg.userauthFailure: throw SSHError.authFailed
            default: throw SSHError.protocolError
            }
        }
    }

    /// Opens a "session" channel and returns the server's channel id.
    private func openSessionChannel() async throws -> UInt32 {
        stage = "channel"
        var open = Data([Msg.channelOpen])
        SSHWire.putString("session", into: &open)
        SSHWire.putUInt32(0, into: &open)              // our channel
        SSHWire.putUInt32(1_048_576, into: &open)      // initial window
        SSHWire.putUInt32(32_768, into: &open)         // max packet
        try await sendPacket(open)

        let confirm = try await expect(Msg.channelOpenConfirm)
        var reader = SSHWire.Reader(confirm)
        _ = reader.readByte()
        _ = reader.readUInt32()                        // our channel
        guard let remote = reader.readUInt32() else { throw SSHError.channelFailed }
        return remote
    }

    // MARK: - Exec

    func run(username: String, auth: SSHAuth, command: String, timeout: Double) async throws -> SSHRunResult {
        defer { connection.cancel() }
        try await establish(username: username, auth: auth, timeout: timeout)
        let remoteChannel = try await openSessionChannel()

        var exec = Data([Msg.channelRequest])
        SSHWire.putUInt32(remoteChannel, into: &exec)
        SSHWire.putString("exec", into: &exec)
        exec.append(1)                                 // want_reply
        SSHWire.putString(command, into: &exec)
        try await sendPacket(exec)

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

            if sinceAdjust >= 524_288 {
                try await sendWindowAdjust(remoteChannel, UInt32(sinceAdjust))
                sinceAdjust = 0
            }
        }

        return SSHRunResult(
            output: String(decoding: output, as: UTF8.self),
            fingerprint: fingerprint,
            hostKeyType: hostKeyTypeName,
            hostKeyVerified: hostKeyVerified,
            exitStatus: exitStatus
        )
    }

    // MARK: - SFTP

    /// Lists a remote directory over the SFTP subsystem (fresh connection).
    func listDirectory(username: String, auth: SSHAuth, path: String, timeout: Double) async throws -> [SFTPEntry] {
        defer { connection.cancel() }
        let channel = try await startSFTP(username: username, auth: auth, timeout: timeout)

        try await sftpSend(channel, SFTPProtocol.openDir(id: 1, path: path))
        let handleReply = try await sftpRead(channel)
        guard let handle = SFTPProtocol.parseHandle(handleReply) else { throw SSHError.channelFailed }

        var entries: [SFTPEntry] = []
        var requestID: UInt32 = 2
        while true {
            try await sftpSend(channel, SFTPProtocol.readDir(id: requestID, handle: handle))
            requestID += 1
            let reply = try await sftpRead(channel)
            guard reply.first == SFTPProtocol.name else { break }   // FXP_STATUS (EOF) ends it
            entries.append(contentsOf: SFTPProtocol.parseName(reply))
        }
        try await sftpSend(channel, SFTPProtocol.close(id: requestID, handle: handle))

        return entries
            .filter { $0.name != "." && $0.name != ".." }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }   // folders first
                return a.name.lowercased() < b.name.lowercased()
            }
    }

    /// Downloads a remote file over SFTP (fresh connection, capped at ~8 MB).
    func downloadFile(username: String, auth: SSHAuth, path: String, timeout: Double) async throws -> Data {
        defer { connection.cancel() }
        let channel = try await startSFTP(username: username, auth: auth, timeout: timeout)

        try await sftpSend(channel, SFTPProtocol.openFile(id: 1, path: path))
        let handleReply = try await sftpRead(channel)
        guard let handle = SFTPProtocol.parseHandle(handleReply) else { throw SSHError.channelFailed }

        var data = Data()
        var offset: UInt64 = 0
        var requestID: UInt32 = 2
        while data.count < 8_000_000 {
            try await sftpSend(channel, SFTPProtocol.readFile(id: requestID, handle: handle, offset: offset, length: 32_768))
            requestID += 1
            let reply = try await sftpRead(channel)
            guard reply.first == SFTPProtocol.data, let chunk = SFTPProtocol.parseData(reply), !chunk.isEmpty else { break }
            data.append(chunk)
            offset += UInt64(chunk.count)
            if chunk.count < 32_768 { break }
        }
        try await sftpSend(channel, SFTPProtocol.close(id: requestID, handle: handle))
        return data
    }

    /// Establishes the session, opens a channel, starts the SFTP subsystem and
    /// completes the SFTP version handshake. Returns the channel id.
    private func startSFTP(username: String, auth: SSHAuth, timeout: Double) async throws -> UInt32 {
        try await establish(username: username, auth: auth, timeout: timeout)
        let channel = try await openSessionChannel()
        try await requestSubsystem(channel, name: "sftp")
        stage = "sftp"
        try await sftpSend(channel, SFTPProtocol.initPacket(version: 3))
        _ = try await sftpRead(channel)                // FXP_VERSION
        return channel
    }

    private func requestSubsystem(_ channel: UInt32, name: String) async throws {
        var request = Data([Msg.channelRequest])
        SSHWire.putUInt32(channel, into: &request)
        SSHWire.putString("subsystem", into: &request)
        request.append(1)                              // want_reply
        SSHWire.putString(name, into: &request)
        try await sendPacket(request)

        while true {
            let payload = try await nextPayload()
            switch payload.first {
            case Msg.channelSuccess: return
            case Msg.channelFailure: throw SSHError.channelFailed
            default: continue                          // window adjust etc.
            }
        }
    }

    /// Wraps an SFTP packet in a CHANNEL_DATA message.
    private func sftpSend(_ channel: UInt32, _ packet: Data) async throws {
        var data = Data([Msg.channelData])
        SSHWire.putUInt32(channel, into: &data)
        SSHWire.putString(packet, into: &data)
        try await sendPacket(data)
    }

    /// Reads one complete SFTP packet (its 4-byte length stripped) from the
    /// stream of channel-data messages.
    private func sftpRead(_ channel: UInt32) async throws -> Data {
        while true {
            if sftpBuffer.count >= 4 {
                let length = (Int(sftpBuffer[0]) << 24) | (Int(sftpBuffer[1]) << 16)
                    | (Int(sftpBuffer[2]) << 8) | Int(sftpBuffer[3])
                if length >= 0, sftpBuffer.count >= 4 + length {
                    let packet = Data(sftpBuffer[4..<4 + length])
                    sftpBuffer.removeFirst(4 + length)
                    return packet
                }
            }
            let payload = try await nextPayload()
            guard let code = payload.first else { continue }
            var reader = SSHWire.Reader(payload)
            _ = reader.readByte()
            switch code {
            case Msg.channelData:
                _ = reader.readUInt32()
                if let chunk = reader.readString() {
                    sftpBuffer.append(contentsOf: chunk)
                    try await sendWindowAdjust(channel, UInt32(chunk.count))
                }
            case Msg.channelClose, Msg.channelEOF:
                throw SSHError.channelFailed
            default:
                break
            }
        }
    }

    // MARK: - Interactive shell (line oriented)

    /// Opens a pty + shell channel and leaves the session running. Drive it
    /// with `readShellChunk()` (a background reader) and `sendShell(_:)`.
    func openShell(username: String, auth: SSHAuth, timeout: Double) async throws {
        try await establish(username: username, auth: auth, timeout: timeout)
        let channel = try await openSessionChannel()
        shellChannel = channel

        var pty = Data([Msg.channelRequest])
        SSHWire.putUInt32(channel, into: &pty)
        SSHWire.putString("pty-req", into: &pty)
        pty.append(0)                                  // want_reply = false
        SSHWire.putString("xterm", into: &pty)
        SSHWire.putUInt32(80, into: &pty)              // columns
        SSHWire.putUInt32(24, into: &pty)              // rows
        SSHWire.putUInt32(0, into: &pty)               // width px
        SSHWire.putUInt32(0, into: &pty)               // height px
        SSHWire.putString(Data([0]), into: &pty)       // empty terminal modes (TTY_OP_END)
        try await sendPacket(pty)

        var shell = Data([Msg.channelRequest])
        SSHWire.putUInt32(channel, into: &shell)
        SSHWire.putString("shell", into: &shell)
        shell.append(0)                                // want_reply = false
        try await sendPacket(shell)
        stage = "shell"
    }

    /// Blocks until the next chunk of shell output arrives; returns nil when
    /// the channel closes. Called only from a single background reader task.
    func readShellChunk() async throws -> String? {
        guard shellChannel != nil else { return nil }
        while true {
            let payload = try await nextPayload()
            guard let code = payload.first else { continue }
            var reader = SSHWire.Reader(payload)
            _ = reader.readByte()
            switch code {
            case Msg.channelData, Msg.channelExtData:
                if code == Msg.channelExtData { _ = reader.readUInt32() }
                _ = reader.readUInt32()
                if let chunk = reader.readString() { return String(decoding: chunk, as: UTF8.self) }
            case Msg.channelClose, Msg.channelEOF:
                return nil
            default:
                continue
            }
        }
    }

    /// Sends user input to the shell. Called only from the UI task, never
    /// concurrently with another send.
    func sendShell(_ text: String) async throws {
        guard let channel = shellChannel else { return }
        var data = Data([Msg.channelData])
        SSHWire.putUInt32(channel, into: &data)
        SSHWire.putString(Data(text.utf8), into: &data)
        try await sendPacket(data)
    }

    private func sendWindowAdjust(_ channel: UInt32, _ bytes: UInt32) async throws {
        var adjust = Data([Msg.channelWindowAdjust])
        SSHWire.putUInt32(channel, into: &adjust)
        SSHWire.putUInt32(bytes, into: &adjust)
        try await sendPacket(adjust)
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
                var line = Array(inbound[0...newline])
                inbound.removeFirst(newline + 1)
                // Trim trailing CR / LF at the BYTE level. Doing it on the
                // decoded String is wrong: Swift fuses "\r\n" into one grapheme
                // cluster, so `hasSuffix("\n")`/`hasSuffix("\r")` both miss it
                // and the CRLF survives — which corrupted V_S in the exchange
                // hash and broke key exchange against every \r\n server.
                while line.last == 0x0A || line.last == 0x0D { line.removeLast() }
                return String(decoding: line, as: UTF8.self)
            }
            try await fill()
        }
    }
}
