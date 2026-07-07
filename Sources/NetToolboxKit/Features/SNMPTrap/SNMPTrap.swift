import SwiftUI
import Observation

/// Best-effort decode of an SNMP message's version + community (BER walk).
enum SNMPTrapDecode {
    static func summary(_ data: Data) -> String {
        let bytes = [UInt8](data)
        guard let seq = tlv(bytes, 0), seq.tag == 0x30,
              let version = tlv(bytes, seq.contentStart), version.tag == 0x02,
              version.length >= 1 else {
            return "\(bytes.count) bytes"
        }
        let versionByte = Int(bytes[version.contentStart])
        let versionName = versionByte == 0 ? "v1" : (versionByte == 1 ? "v2c" : "v\(versionByte)")
        guard let community = tlv(bytes, version.contentStart + version.length), community.tag == 0x04 else {
            return "SNMP \(versionName)"
        }
        let text = String(decoding: bytes[community.contentStart..<community.contentStart + community.length], as: UTF8.self)
        return "SNMP \(versionName) · community: \(text)"
    }

    static func tlv(_ bytes: [UInt8], _ start: Int) -> (tag: UInt8, contentStart: Int, length: Int)? {
        guard start + 1 < bytes.count else { return nil }
        let tag = bytes[start]
        var index = start + 1
        var length = Int(bytes[index]); index += 1
        if length & 0x80 != 0 {
            let count = length & 0x7F
            length = 0
            for _ in 0..<count {
                guard index < bytes.count else { return nil }
                length = (length << 8) | Int(bytes[index]); index += 1
            }
        }
        guard index + length <= bytes.count else { return nil }
        return (tag, index, length)
    }
}

@MainActor
@Observable
final class SNMPTrapViewModel {
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let sender: String
        let summary: String
        let hex: String
    }

    var portText = "1162"
    private(set) var traps: [Entry] = []
    private(set) var isListening = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isListening else { return }
            if isListening { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }
    private(set) var errorMessage: String?

    var activity: ActivityCenter?
    var toolID = ""

    private let listener = UDPListener()

    func toggle() {
        if isListening { stop() } else { start() }
    }

    private func start() {
        guard let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        errorMessage = nil
        listener.onReady = { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.isListening = true } }
        }
        listener.onError = { [weak self] message in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.errorMessage = message; self?.isListening = false } }
        }
        listener.onDatagram = { [weak self] data, sender in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.append(sender: sender, data: data) } }
        }
        listener.start(port: port)
    }

    func stop() {
        listener.stop()
        isListening = false
    }

    func clear() { traps = [] }

    private func append(sender: String, data: Data) {
        let hex = data.prefix(48).map { String(format: "%02x", $0) }.joined(separator: " ")
        traps.insert(Entry(sender: sender, summary: SNMPTrapDecode.summary(data), hex: hex), at: 0)
        if traps.count > 200 { traps.removeLast(traps.count - 200) }
    }
}

struct SNMPTrapTool: NetworkTool {
    let id = "snmp-trap"
    let titleKey = L10n("tool.snmptrap.title")
    let subtitleKey = L10n("tool.snmptrap.subtitle")
    let systemImage = "antenna.radiowaves.left.and.right.circle"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(SNMPTrapView()) }
}

@MainActor
struct SNMPTrapView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: SNMPTrapViewModel {
        sessions.session("snmp-trap") {
            let model = SNMPTrapViewModel()
            model.activity = activity
            model.toolID = "snmp-trap"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                controlSection
                if !viewModel.traps.isEmpty {
                    trapsSection
                }
                Text(L10n("snmptrap.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.snmptrap.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var controlSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("snmptrap.input.title"), systemImage: "antenna.radiowaves.left.and.right.circle") {
            HStack(spacing: Spacing.md) {
                TextField("1162", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numberPad).frame(maxWidth: 100)
                    .environment(\.layoutDirection, .leftToRight)
                    .disabled(viewModel.isListening)
                Button {
                    viewModel.toggle()
                } label: {
                    Label(
                        L10nString(viewModel.isListening ? "syslog.action.stop" : "syslog.action.listen"),
                        systemImage: viewModel.isListening ? "stop.circle" : "play.circle"
                    )
                    .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
                if viewModel.isListening {
                    StatusBadge(kind: .success, text: L10n("syslog.listening"))
                }
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private var trapsSection: some View {
        SectionCard(title: L10n("snmptrap.section.traps"), systemImage: "text.alignleft") {
            ForEach(viewModel.traps) { trap in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(trap.summary).font(AppTypography.caption.weight(.semibold)).foregroundStyle(theme.accent)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        Text(trap.sender).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    Text(trap.hex).font(AppTypography.monoCaption).foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Divider().overlay(theme.separator)
            }
            Button { viewModel.clear() } label: {
                Label(L10nString("common.clear"), systemImage: "trash").font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)
        }
    }
}
