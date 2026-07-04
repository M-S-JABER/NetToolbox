import SwiftUI
import Observation

@MainActor
@Observable
final class MQTTViewModel {
    struct Entry: Identifiable, Sendable {
        enum Kind: Sendable { case system, outgoing, message, error }
        let id = UUID()
        let kind: Kind
        let text: String
    }

    var host = "test.mosquitto.org"
    var portText = "1883"
    var useTLS = false
    var clientID = ""
    var username = ""
    var password = ""
    var topic = "nettoolbox/test"
    var publishText = ""

    private(set) var log: [Entry] = []
    private(set) var isConnected = false {
        didSet {
            guard !toolID.isEmpty, oldValue != isConnected else { return }
            if isConnected { activity?.start(toolID) } else { activity?.stop(toolID) }
        }
    }

    var activity: ActivityCenter?
    var toolID = ""

    private var client: MQTTClient?

    func connect() {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard !trimmedHost.isEmpty else { return }
        let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) ?? 1883
        let identifier = clientID.trimmingCharacters(in: .whitespaces).isEmpty
            ? "nettoolbox-\(String(format: "%06x", UInt32.random(in: 0...0xFFFFFF)))"
            : clientID

        let client = MQTTClient(
            host: trimmedHost, port: port, tls: useTLS,
            clientID: identifier, username: username, password: password
        )
        client.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.handle(event) }
            }
        }
        self.client = client
        append(.system, L10nString("mqtt.status.connecting"))
        client.connect()
    }

    func subscribe() {
        let target = topic.trimmingCharacters(in: .whitespaces)
        guard isConnected, !target.isEmpty else { return }
        client?.subscribe(topic: target)
        append(.outgoing, "SUB \(target)")
    }

    func publish() {
        let target = topic.trimmingCharacters(in: .whitespaces)
        let payload = publishText
        guard isConnected, !target.isEmpty, !payload.isEmpty else { return }
        client?.publish(topic: target, message: payload)
        append(.outgoing, "PUB \(target) → \(payload)")
        publishText = ""
    }

    func disconnect() {
        client?.disconnect()
    }

    func clear() {
        log = []
    }

    private func handle(_ event: MQTTClient.Event) {
        switch event {
        case .connected:
            isConnected = true
            append(.system, L10nString("mqtt.status.connected"))
        case .subscribed:
            append(.system, L10nString("mqtt.status.subscribed"))
        case .message(let topic, let payload):
            append(.message, "\(topic) ▸ \(payload)")
        case .disconnected:
            isConnected = false
            append(.system, L10nString("mqtt.status.disconnected"))
        case .error(let message):
            isConnected = false
            append(.error, message)
        }
    }

    private func append(_ kind: Entry.Kind, _ text: String) {
        log.append(Entry(kind: kind, text: text))
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }
}

struct MQTTTool: NetworkTool {
    let id = "mqtt"
    let titleKey = L10n("tool.mqtt.title")
    let subtitleKey = L10n("tool.mqtt.subtitle")
    let systemImage = "antenna.radiowaves.left.and.right"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(MQTTView()) }
}

struct MQTTView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity

    private var viewModel: MQTTViewModel {
        sessions.session("mqtt") {
            let model = MQTTViewModel()
            model.activity = activity
            model.toolID = "mqtt"
            return model
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                connectionSection
                if viewModel.isConnected {
                    topicSection
                }
                if !viewModel.log.isEmpty {
                    logSection
                }
                Text(L10n("mqtt.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.mqtt.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var connectionSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("mqtt.section.connection"), systemImage: "antenna.radiowaves.left.and.right") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("mqtt.field.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                    .disabled(viewModel.isConnected)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.md) {
                labeled(L10n("mqtt.field.port")) {
                    TextField("1883", text: $viewModel.portText)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 90)
                        .environment(\.layoutDirection, .leftToRight)
                        .disabled(viewModel.isConnected)
                }
                Toggle(isOn: $viewModel.useTLS) {
                    Text(L10n("mqtt.field.tls")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                }
                .disabled(viewModel.isConnected)
            }
            TextField(L10nString("mqtt.field.clientID"), text: $viewModel.clientID)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .disabled(viewModel.isConnected)
            HStack(spacing: Spacing.md) {
                TextField(L10nString("mqtt.field.username"), text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                    .disabled(viewModel.isConnected)
                SecureField(L10nString("mqtt.field.password"), text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .environment(\.layoutDirection, .leftToRight)
                    .disabled(viewModel.isConnected)
            }

            if viewModel.isConnected {
                Button(role: .destructive) {
                    viewModel.disconnect()
                } label: {
                    Label(L10nString("mqtt.action.disconnect"), systemImage: "xmark.circle")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    viewModel.connect()
                } label: {
                    Label(L10nString("mqtt.action.connect"), systemImage: "bolt.horizontal")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var topicSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("mqtt.section.topic"), systemImage: "number") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("mqtt.field.topic"), text: $viewModel.topic)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    viewModel.subscribe()
                } label: {
                    Label(L10nString("mqtt.action.subscribe"), systemImage: "arrow.down.circle")
                        .font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("mqtt.field.publish"), text: $viewModel.publishText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .environment(\.layoutDirection, .leftToRight)
                Button {
                    viewModel.publish()
                } label: {
                    Image(systemName: "paperplane.fill").font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.publishText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var logSection: some View {
        SectionCard(title: L10n("mqtt.section.log"), systemImage: "text.alignleft") {
            ForEach(viewModel.log) { entry in
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

    private func labeled(_ label: LocalizedStringResource, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func icon(for kind: MQTTViewModel.Entry.Kind) -> String {
        switch kind {
        case .system: return "info.circle"
        case .outgoing: return "arrow.up"
        case .message: return "arrow.down"
        case .error: return "exclamationmark.triangle"
        }
    }

    private func color(for kind: MQTTViewModel.Entry.Kind) -> Color {
        switch kind {
        case .system: return theme.textSecondary
        case .outgoing: return theme.accent
        case .message: return theme.textPrimary
        case .error: return theme.danger
        }
    }
}
