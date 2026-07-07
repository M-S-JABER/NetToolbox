import SwiftUI
import Observation

/// Extracts the severity from a syslog `<PRI>` prefix (RFC 3164/5424).
enum SyslogParse {
    static let severities = ["emerg", "alert", "crit", "err", "warning", "notice", "info", "debug"]

    static func severity(_ message: String) -> String? {
        guard message.hasPrefix("<"), let close = message.firstIndex(of: ">"),
              let pri = Int(message[message.index(after: message.startIndex)..<close]) else {
            return nil
        }
        return severities[pri % 8]
    }
}

@MainActor
@Observable
final class SyslogViewModel {
    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let sender: String
        let severity: String?
        let text: String
    }

    var portText = "5140"
    private(set) var messages: [Entry] = []
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

    func clear() { messages = [] }

    private func append(sender: String, data: Data) {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        messages.insert(Entry(sender: sender, severity: SyslogParse.severity(text), text: text), at: 0)
        if messages.count > 300 { messages.removeLast(messages.count - 300) }
    }
}

struct SyslogTool: NetworkTool {
    let id = "syslog"
    let titleKey = L10n("tool.syslog.title")
    let subtitleKey = L10n("tool.syslog.subtitle")
    let systemImage = "doc.plaintext"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(SyslogView()) }
}

@MainActor
struct SyslogView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: SyslogViewModel {
        sessions.session("syslog") {
            let model = SyslogViewModel()
            model.activity = activity
            model.toolID = "syslog"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                controlSection
                if !viewModel.messages.isEmpty {
                    messagesSection
                }
                Text(L10n("syslog.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.syslog.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var controlSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("syslog.input.title"), systemImage: "doc.plaintext") {
            HStack(spacing: Spacing.md) {
                TextField("5140", text: $viewModel.portText)
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

    private var messagesSection: some View {
        SectionCard(title: L10n("syslog.section.messages"), systemImage: "text.alignleft") {
            ForEach(viewModel.messages) { message in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        if let severity = message.severity {
                            Text(severity.uppercased())
                                .font(AppTypography.monoCaption.weight(.bold))
                                .foregroundStyle(theme.accent)
                        }
                        Text(message.sender).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                    }
                    Text(message.text).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
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
