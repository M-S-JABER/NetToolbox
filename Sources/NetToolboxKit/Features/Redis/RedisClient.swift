import SwiftUI
import Observation

/// Minimal RESP (REdis Serialization Protocol) reader/formatter.
enum RESP {
    static func encode(command: String) -> Data {
        Data((command.trimmingCharacters(in: .whitespacesAndNewlines) + "\r\n").utf8)
    }

    static func format(_ data: Data) -> String {
        let bytes = [UInt8](data)
        var index = 0
        var lines: [String] = []
        while index < bytes.count, let (text, next) = parse(bytes, index, depth: 0) {
            lines.append(text)
            index = next
        }
        return lines.isEmpty ? String(decoding: data, as: UTF8.self) : lines.joined(separator: "\n")
    }

    private static func parse(_ bytes: [UInt8], _ start: Int, depth: Int) -> (String, Int)? {
        guard start < bytes.count, let lineEnd = crlf(bytes, from: start + 1) else { return nil }
        let header = String(decoding: bytes[(start + 1)..<lineEnd], as: UTF8.self)
        let after = lineEnd + 2
        let indent = String(repeating: "  ", count: depth)
        switch bytes[start] {
        case 0x2B: return ("\(indent)\(header)", after)                    // + simple string
        case 0x2D: return ("\(indent)(error) \(header)", after)            // - error
        case 0x3A: return ("\(indent)(integer) \(header)", after)          // : integer
        case 0x24:                                                          // $ bulk string
            guard let length = Int(header) else { return ("\(indent)(nil)", after) }
            if length < 0 { return ("\(indent)(nil)", after) }
            let end = after + length
            guard end <= bytes.count else { return nil }
            return ("\(indent)\"\(String(decoding: bytes[after..<end], as: UTF8.self))\"", end + 2)
        case 0x2A:                                                          // * array
            guard let count = Int(header) else { return ("\(indent)(empty array)", after) }
            var idx = after
            var parts = ["\(indent)(array of \(count))"]
            for _ in 0..<max(0, count) {
                guard let (text, next) = parse(bytes, idx, depth: depth + 1) else { break }
                parts.append(text)
                idx = next
            }
            return (parts.joined(separator: "\n"), idx)
        default:
            return ("\(indent)\(String(decoding: bytes[start..<lineEnd], as: UTF8.self))", after)
        }
    }

    private static func crlf(_ bytes: [UInt8], from: Int) -> Int? {
        var i = from
        while i + 1 < bytes.count {
            if bytes[i] == 0x0D, bytes[i + 1] == 0x0A { return i }
            i += 1
        }
        return nil
    }
}

struct RedisService: Sendable {
    func run(host: String, port: UInt16, password: String, command: String, tls: Bool) async -> Result<String, String> {
        guard let connection = TCPConnection(host: host, port: port, tls: tls) else {
            return .failure(L10nString("banner.error.host"))
        }
        if case .failure(let error) = await connection.open(timeout: 6) {
            connection.cancel()
            return .failure(error.localizedDescription)
        }
        if !password.isEmpty {
            _ = await connection.send(RESP.encode(command: "AUTH \(password)"))
            _ = await connection.receive()
        }
        _ = await connection.send(RESP.encode(command: command))
        let result = await connection.receiveAll(timeout: 3)
        connection.cancel()
        switch result {
        case .success(let data): return .success(RESP.format(data))
        case .failure(let error): return .failure(error.localizedDescription)
        }
    }
}

@MainActor
@Observable
final class RedisViewModel {
    var host = ""
    var portText = "6379"
    var password = ""
    var command = "PING"
    var tls = false
    private(set) var output: String?
    private(set) var errorMessage: String?
    private(set) var isRunning = false

    private let service = RedisService()

    func run() async {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) else { return }
        isRunning = true
        output = nil
        errorMessage = nil
        let result = await service.run(host: target, port: port, password: password, command: command, tls: tls)
        switch result {
        case .success(let text): output = text
        case .failure(let message): errorMessage = message
        }
        isRunning = false
    }
}

struct RedisTool: NetworkTool {
    let id = "redis"
    let titleKey = L10n("tool.redis.title")
    let subtitleKey = L10n("tool.redis.subtitle")
    let systemImage = "cylinder.split.1x2"
    let category: ToolCategory = .professional

    func makeView() -> AnyView { AnyView(RedisView()) }
}

struct RedisView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = RedisViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(AppTypography.footnote).foregroundStyle(theme.danger)
                }
                if let output = viewModel.output {
                    SectionCard(title: L10n("redis.section.reply"), systemImage: "text.alignleft") {
                        Text(output).font(AppTypography.monoCaption).foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, .leftToRight)
                        CopyButton(value: output)
                    }
                }
                Text(L10n("redis.note")).font(AppTypography.caption).foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.redis.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("redis.input.title"), systemImage: "cylinder.split.1x2") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("redis.input.host"), text: $viewModel.host)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    .environment(\.layoutDirection, .leftToRight)
                SavedHostMenu(host: $viewModel.host)
            }
            HStack(spacing: Spacing.md) {
                TextField("6379", text: $viewModel.portText)
                    .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                    .keyboardType(.numberPad).frame(maxWidth: 90)
                    .environment(\.layoutDirection, .leftToRight)
                Toggle(isOn: $viewModel.tls) {
                    Text(L10n("banner.tls")).font(AppTypography.body).foregroundStyle(theme.textPrimary)
                }
            }
            SecureField(L10nString("redis.input.password"), text: $viewModel.password)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .environment(\.layoutDirection, .leftToRight)
            TextField(L10nString("redis.input.command"), text: $viewModel.command)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            Button {
                Task { await viewModel.run() }
            } label: {
                Label(L10nString("redis.action.send"), systemImage: "paperplane").font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent).disabled(viewModel.isRunning)
            if viewModel.isRunning { ProgressView() }
        }
    }
}
