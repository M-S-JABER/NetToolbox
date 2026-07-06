import Foundation
#if canImport(Darwin)
import Darwin
#endif
import SwiftUI
import Observation

/// A TFTP (RFC 1350) read client. TFTP replies come from a *new* source port
/// (the transfer ID), which connected UDP would filter out — so this uses a
/// raw, unconnected `SOCK_DGRAM` socket and ACKs each block back to whatever
/// address the DATA arrived from.
struct TFTPClient: Sendable {
    /// The Read Request packet bytes (opcode 1, filename, "octet" mode).
    static func rrqPacket(filename: String) -> [UInt8] {
        let clean = filename.hasPrefix("/") ? String(filename.dropFirst()) : filename
        var bytes: [UInt8] = [0x00, 0x01]
        bytes.append(contentsOf: Array(clean.utf8)); bytes.append(0)
        bytes.append(contentsOf: Array("octet".utf8)); bytes.append(0)
        return bytes
    }

    func download(host: String, port: UInt16, filename: String, maxBytes: Int) async -> Result<Data, String> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: Self.transfer(host: host, port: port, filename: filename, maxBytes: maxBytes))
            }
        }
    }

    #if canImport(Darwin)
    private static func transfer(host: String, port: UInt16, filename: String, maxBytes: Int) -> Result<Data, String> {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        var info: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &info) == 0, let info else {
            return .failure(L10nString("tftp.error.resolve"))
        }
        defer { freeaddrinfo(info) }

        var serverAddr = sockaddr_storage()
        memcpy(&serverAddr, info.pointee.ai_addr, Int(info.pointee.ai_addrlen))
        let serverLen = info.pointee.ai_addrlen

        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return .failure(L10nString("tftp.error.socket")) }
        defer { close(fd) }
        var tv = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let rrq = rrqPacket(filename: filename)
        let sent = rrq.withUnsafeBytes { raw in
            withUnsafePointer(to: &serverAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, rrq.count, 0, sa, serverLen)
                }
            }
        }
        guard sent >= 0 else { return .failure(L10nString("tftp.error.socket")) }

        var data = Data()
        var expected: UInt16 = 1
        var buffer = [UInt8](repeating: 0, count: 516)
        var fromAddr = sockaddr_storage()

        while true {
            var fromLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let n = withUnsafeMutablePointer(to: &fromAddr) { ap in
                ap.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(fd, &buffer, buffer.count, 0, sa, &fromLen)
                }
            }
            if n < 0 { return data.isEmpty ? .failure(L10nString("tftp.error.timeout")) : .success(data) }
            if n < 4 { continue }

            let opcode = Int(buffer[0]) << 8 | Int(buffer[1])
            if opcode == 5 { // ERROR
                let message = n > 5 ? String(decoding: buffer[4..<(n - 1)], as: UTF8.self) : L10nString("tftp.error.server")
                return .failure(message)
            }
            if opcode != 3 { continue } // only DATA

            // ACK back to the transfer-ID address the DATA came from.
            let ack: [UInt8] = [0x00, 0x04, buffer[2], buffer[3]]
            _ = ack.withUnsafeBytes { raw in
                withUnsafePointer(to: &fromAddr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        sendto(fd, raw.baseAddress, ack.count, 0, sa, fromLen)
                    }
                }
            }

            let block = UInt16(buffer[2]) << 8 | UInt16(buffer[3])
            if block == expected {
                let chunk = n > 4 ? Array(buffer[4..<n]) : []
                data.append(contentsOf: chunk)
                expected = expected &+ 1
                if chunk.count < 512 { return .success(data) }
                if data.count > maxBytes { return .failure(L10nString("tftp.error.tooLarge")) }
            }
        }
    }
    #else
    private static func transfer(host: String, port: UInt16, filename: String, maxBytes: Int) -> Result<Data, String> {
        .failure("Unsupported platform")
    }
    #endif
}

@MainActor
@Observable
final class TFTPViewModel {
    var host = ""
    var portText = "69"
    var filename = ""
    private(set) var savedURL: URL?
    private(set) var preview = ""
    private(set) var byteCount = 0
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    private let client = TFTPClient()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        let name = filename.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, !name.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        errorMessage = nil
        savedURL = nil
        preview = ""
        byteCount = 0

        let result = await client.download(host: target, port: port, filename: name, maxBytes: 2_000_000)
        switch result {
        case .success(let data):
            byteCount = data.count
            preview = String(decoding: data.prefix(3000), as: UTF8.self)
            if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let safeName = (name as NSString).lastPathComponent
                let url = directory.appendingPathComponent(safeName.isEmpty ? "tftp-download" : safeName)
                try? data.write(to: url)
                savedURL = url
            }
        case .failure(let message):
            errorMessage = message
        }
        isRunning = false
    }
}

struct TFTPTool: NetworkTool {
    let id = "tftp"
    let titleKey = L10n("tool.tftp.title")
    let subtitleKey = L10n("tool.tftp.subtitle")
    let systemImage = "arrow.down.doc"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(TFTPView()) }
}

struct TFTPView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = TFTPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if viewModel.byteCount > 0 {
                    resultSection
                }
                Text(L10n("tftp.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.tftp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("tftp.input.title"), systemImage: "arrow.down.doc") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("banner.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.md) {
                TextField("69", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numberPad).frame(maxWidth: 80)
                    .environment(\.layoutDirection, .leftToRight)
                TextField(L10nString("tftp.input.filename"), text: $viewModel.filename)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("tftp.action.download"), systemImage: "arrow.down.circle").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }

    private var resultSection: some View {
        SectionCard(title: L10n("tftp.section.result"), systemImage: "doc") {
            HStack {
                StatusBadge(kind: .success, text: L10n("tftp.downloaded"))
                Text(String(format: "%d bytes", viewModel.byteCount))
                    .font(AppTypography.monoBody).foregroundStyle(theme.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
            }
            if !viewModel.preview.isEmpty {
                Text(viewModel.preview).font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
            }
            if let url = viewModel.savedURL {
                ShareLink(item: url) {
                    Label(L10nString("common.share"), systemImage: "square.and.arrow.up").font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
