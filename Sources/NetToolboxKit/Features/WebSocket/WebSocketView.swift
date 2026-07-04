import SwiftUI
import Observation

@MainActor
@Observable
final class WebSocketViewModel {
    struct Entry: Identifiable, Sendable {
        enum Kind: Sendable { case sent, received, system, error }
        let id = UUID()
        let kind: Kind
        let text: String
    }

    var url = "wss://echo.websocket.events"
    var message = ""
    private(set) var transcript: [Entry] = []
    private(set) var isConnected = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isConnected else { return }
            if isConnected { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }

    var activity: ActivityCenter?
    var toolID = ""

    private let client = WebSocketClient()

    func connect() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard let target = URL(string: trimmed), target.scheme == "ws" || target.scheme == "wss" else {
            append(.error, L10nString("websocket.error.url"))
            return
        }
        client.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handle(event) }
            }
        }
        append(.system, L10nString("websocket.status.connecting"))
        client.connect(url: target)
    }

    func send() {
        let text = message
        guard isConnected, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        client.send(text)
        append(.sent, text)
        message = ""
    }

    func disconnect() {
        client.disconnect()
        if isConnected {
            isConnected = false
            append(.system, L10nString("websocket.status.closed"))
        }
    }

    func clear() {
        transcript = []
    }

    private func handle(_ event: WebSocketClient.Event) {
        switch event {
        case .open:
            isConnected = true
            append(.system, L10nString("websocket.status.connected"))
        case .text(let text):
            append(.received, text)
        case .binary(let count):
            append(.received, "‹\(count) bytes›")
        case .closed(let reason):
            isConnected = false
            append(.system, reason.map { "\(L10nString("websocket.status.closed")): \($0)" } ?? L10nString("websocket.status.closed"))
        case .error(let message):
            isConnected = false
            append(.error, message)
        }
    }

    private func append(_ kind: Entry.Kind, _ text: String) {
        transcript.append(Entry(kind: kind, text: text))
        if transcript.count > 300 { transcript.removeFirst(transcript.count - 300) }
    }
}

struct WebSocketTool: NetworkTool {
    let id = "websocket"
    let titleKey = L10n("tool.websocket.title")
    let subtitleKey = L10n("tool.websocket.subtitle")
    let systemImage = "bolt.horizontal.circle"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(WebSocketView()) }
}

struct WebSocketView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: WebSocketViewModel {
        sessions.session("websocket") {
            let model = WebSocketViewModel()
            model.activity = activity
            model.toolID = "websocket"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if viewModel.isConnected {
                    sendSection
                }
                if !viewModel.transcript.isEmpty {
                    transcriptSection
                }
                Text(L10n("websocket.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.websocket.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var connectionSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("websocket.input.title"), systemImage: "bolt.horizontal.circle") {
            TextField(L10nString("websocket.input.url"), text: $viewModel.url)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
                .disabled(viewModel.isConnected)

            if viewModel.isConnected {
                Button(role: .destructive) {
                    viewModel.disconnect()
                } label: {
                    Label(L10nString("websocket.action.disconnect"), systemImage: "xmark.circle")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    viewModel.connect()
                } label: {
                    Label(L10nString("websocket.action.connect"), systemImage: "bolt.horizontal")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var sendSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("websocket.input.message"), systemImage: "paperplane") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("websocket.input.message"), text: $viewModel.message, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .lineLimit(1...4)
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.message.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var transcriptSection: some View {
        SectionCard(title: L10n("websocket.section.transcript"), systemImage: "text.alignleft") {
            ForEach(viewModel.transcript) { entry in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: icon(for: entry.kind))
                        .font(.caption2)
                        .foregroundStyle(color(for: entry.kind))
                        .frame(width: 16)
                    Text(entry.text)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(color(for: entry.kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Button {
                viewModel.clear()
            } label: {
                Label(L10nString("common.clear"), systemImage: "trash")
                    .font(AppTypography.footnote)
            }
            .buttonStyle(.bordered)
        }
    }

    private func icon(for kind: WebSocketViewModel.Entry.Kind) -> String {
        switch kind {
        case .sent: return "arrow.up"
        case .received: return "arrow.down"
        case .system: return "info.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    private func color(for kind: WebSocketViewModel.Entry.Kind) -> Color {
        switch kind {
        case .sent: return theme.accent
        case .received: return theme.textPrimary
        case .system: return theme.textSecondary
        case .error: return theme.danger
        }
    }
}
