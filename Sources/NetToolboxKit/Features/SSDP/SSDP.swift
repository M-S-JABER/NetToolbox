import SwiftUI
import Observation
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Model

struct SSDPDevice: Identifiable, Equatable, Sendable {
    let address: String
    let location: String
    let server: String
    let searchTarget: String
    let usn: String

    var id: String { usn.isEmpty ? "\(address)|\(location)" : usn }
}

enum SSDPEngine {
    /// Parses an SSDP/HTTPU response into a device record.
    static func parse(_ text: String, address: String) -> SSDPDevice {
        func header(_ name: String) -> String {
            for line in text.split(whereSeparator: \.isNewline) {
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                if parts[0].trimmingCharacters(in: .whitespaces).uppercased() == name {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
            return ""
        }
        return SSDPDevice(
            address: address,
            location: header("LOCATION"),
            server: header("SERVER"),
            searchTarget: header("ST"),
            usn: header("USN")
        )
    }

    /// Blocking multicast discovery. Runs off the main actor. On iOS this
    /// requires the multicast networking entitlement; without it the send
    /// fails and no devices are returned.
    static func discover(searchTarget: String, timeout: Double) async -> [SSDPDevice] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[SSDPDevice], Never>) in
            let shot = OneShot(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                shot.resume(blockingDiscover(searchTarget: searchTarget, timeout: timeout))
            }
        }
    }

    #if canImport(Darwin)
    private static func blockingDiscover(searchTarget: String, timeout: Double) -> [SSDPDevice] {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var ttl: Int32 = 2
        setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<Int32>.size))
        var tv = timeval(tv_sec: 1, tv_usec: 0)   // per-recv timeout; loop until the deadline
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var local = sockaddr_in()
        local.sin_family = sa_family_t(AF_INET)
        local.sin_addr.s_addr = INADDR_ANY
        local.sin_port = 0
        _ = withUnsafePointer(to: &local) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = in_port_t(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &dest.sin_addr)

        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: 239.255.255.250:1900\r
        MAN: "ssdp:discover"\r
        MX: 2\r
        ST: \(searchTarget)\r
        \r

        """
        let payload = Array(message.utf8)
        let sent = payload.withUnsafeBytes { buffer -> Int in
            withUnsafePointer(to: &dest) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buffer.baseAddress, buffer.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return [] }   // multicast entitlement missing, etc.

        var devices: [String: SSDPDevice] = [:]
        var buffer = [UInt8](repeating: 0, count: 2048)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var source = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &source) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, buffer.count, 0, $0, &sourceLength)
                }
            }
            if received <= 0 { continue }   // per-recv timeout — keep waiting
            let text = String(decoding: buffer[0..<received], as: UTF8.self)
            var addressBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &source.sin_addr, &addressBuffer, socklen_t(INET_ADDRSTRLEN))
            let device = parse(text, address: String(cBuffer: addressBuffer))
            devices[device.id] = device
        }
        return Array(devices.values).sorted { $0.address < $1.address }
    }
    #else
    private static func blockingDiscover(searchTarget: String, timeout: Double) -> [SSDPDevice] { [] }
    #endif
}

// MARK: - ViewModel

@MainActor
@Observable
final class SSDPViewModel {
    var searchTarget = "ssdp:all"
    private(set) var devices: [SSDPDevice] = []
    private(set) var isScanning = false
    private(set) var didScan = false

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        didScan = false
        devices = await SSDPEngine.discover(searchTarget: searchTarget, timeout: 4)
        didScan = true
        isScanning = false
    }
}

// MARK: - Tool

struct SSDPTool: NetworkTool {
    let id = "ssdp"
    let titleKey = L10n("tool.ssdp.title")
    let subtitleKey = L10n("tool.ssdp.subtitle")
    let systemImage = "sparkles.tv"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(SSDPView()) }
}

// MARK: - View

@MainActor
struct SSDPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = SSDPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if !viewModel.devices.isEmpty {
                    devicesSection
                } else if viewModel.didScan {
                    emptySection
                }
                noteSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ssdp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("ssdp.input.title"), systemImage: "antenna.radiowaves.left.and.right") {
            Picker(L10nString("ssdp.opt.target"), selection: $viewModel.searchTarget) {
                Text("ssdp:all").tag("ssdp:all")
                Text("UPnP root").tag("upnp:rootdevice")
                Text("MediaServer").tag("urn:schemas-upnp-org:device:MediaServer:1")
                Text("IGD (router)").tag("urn:schemas-upnp-org:device:InternetGatewayDevice:1")
            }
            .pickerStyle(.menu)

            Button {
                Task { await viewModel.scan() }
            } label: {
                Label(L10nString("ssdp.action.scan"), systemImage: "dot.radiowaves.left.and.right")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning)
            if viewModel.isScanning { ProgressView() }
        }
    }

    private var devicesSection: some View {
        SectionCard(title: L10n("ssdp.section.devices"), systemImage: "tv.and.hifispeaker.fill") {
            ForEach(viewModel.devices) { device in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(device.address)
                            .font(AppTypography.monoBody)
                            .foregroundStyle(theme.textPrimary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        if !device.server.isEmpty {
                            Text(device.server)
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    if !device.location.isEmpty {
                        Text(device.location)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    if !device.searchTarget.isEmpty {
                        Text(device.searchTarget)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                if device.id != viewModel.devices.last?.id {
                    Divider().overlay(theme.separator)
                }
            }
        }
    }

    private var emptySection: some View {
        SectionCard(title: L10n("ssdp.section.devices"), systemImage: "questionmark.circle") {
            Text(L10n("ssdp.empty"))
                .font(AppTypography.body)
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var noteSection: some View {
        Text(L10n("ssdp.note"))
            .font(AppTypography.caption)
            .foregroundStyle(theme.textSecondary)
    }
}
