import SwiftUI
import Observation

/// Minimal CoAP (RFC 7252) GET encoding and response parsing over UDP.
enum CoAP {
    /// A confirmable GET for `path`, with Uri-Path options.
    static func get(path: String, messageID: UInt16) -> Data {
        var bytes: [UInt8] = [0x40, 0x01, UInt8(messageID >> 8), UInt8(messageID & 0xFF)]
        var lastOption = 0
        for segment in path.split(separator: "/").map(String.init) {
            let delta = 11 - lastOption // Uri-Path is option number 11
            lastOption = 11
            let value = [UInt8](segment.utf8)
            let deltaNibble = delta < 13 ? delta : 13
            let lenNibble = value.count < 13 ? value.count : 13
            bytes.append(UInt8((deltaNibble << 4) | lenNibble))
            if delta >= 13 { bytes.append(UInt8(delta - 13)) }
            if value.count >= 13 { bytes.append(UInt8(value.count - 13)) }
            bytes.append(contentsOf: value)
        }
        return Data(bytes)
    }

    /// (response code like "2.05", payload text).
    static func parse(_ data: Data) -> (code: String, payload: String)? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else { return nil }
        let code = bytes[1]
        let codeString = "\(code >> 5).\(String(format: "%02d", code & 0x1F))"
        if let marker = bytes.firstIndex(of: 0xFF) {
            return (codeString, String(decoding: bytes[(marker + 1)...], as: UTF8.self))
        }
        return (codeString, "")
    }
}

@MainActor
@Observable
final class CoAPViewModel {
    var host = ""
    var portText = "5683"
    var path = "test"
    private(set) var code: String?
    private(set) var payload = ""
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        errorMessage = nil
        code = nil
        payload = ""
        let request = CoAP.get(path: path.trimmingCharacters(in: .whitespaces), messageID: UInt16.random(in: 0...UInt16.max))
        let result = await UDPExchange.request(host: target, port: port, payload: request, timeout: 5)
        switch result {
        case .success(let data):
            if let parsed = CoAP.parse(data) {
                code = parsed.code
                payload = parsed.payload
            } else {
                errorMessage = L10nString("coap.badResponse")
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}

struct CoAPTool: NetworkTool {
    let id = "coap"
    let titleKey = L10n("tool.coap.title")
    let subtitleKey = L10n("tool.coap.subtitle")
    let systemImage = "sensor.tag.radiowaves.forward"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(CoAPView()) }
}

struct CoAPView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = CoAPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if let code = viewModel.code {
                    SectionCard(title: L10n("coap.section.response"), systemImage: "arrow.down.circle") {
                        HStack {
                            StatusBadge(kind: code.hasPrefix("2") ? .success : .warning, text: L10n("coap.code"))
                            Text(code).font(AppTypography.monoBody).foregroundStyle(theme.textPrimary)
                                .environment(\.layoutDirection, .leftToRight)
                        }
                        if !viewModel.payload.isEmpty {
                            Text(viewModel.payload).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.layoutDirection, .leftToRight)
                            CopyButton(value: viewModel.payload)
                        }
                    }
                }
                Text(L10n("coap.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.coap.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("coap.input.title"), systemImage: "sensor.tag.radiowaves.forward") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("banner.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.md) {
                TextField("5683", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numberPad).frame(maxWidth: 100)
                    .environment(\.layoutDirection, .leftToRight)
                TextField(L10nString("coap.input.path"), text: $viewModel.path)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("coap.action.get"), systemImage: "arrow.down.circle").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }
}
