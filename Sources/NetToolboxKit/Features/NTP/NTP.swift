import SwiftUI
import Observation

/// Pure SNTP (RFC 4330) request builder and response parser. Unit-tested;
/// the UDP transport is `UDPExchange`.
enum NTP {
    /// Seconds between the NTP epoch (1900-01-01) and the Unix epoch.
    static let ntpToUnixOffset: UInt32 = 2_208_988_800

    /// A 48-byte client request: LI=0, VN=3, Mode=3 (client), rest zeroed.
    static func request() -> Data {
        var bytes = [UInt8](repeating: 0, count: 48)
        bytes[0] = 0x1B
        return Data(bytes)
    }

    /// Parses the transmit timestamp (bytes 40–43) into a `Date`.
    static func parse(_ data: Data) -> Date? {
        let bytes = [UInt8](data)
        guard bytes.count >= 44 else { return nil }
        let seconds = (UInt32(bytes[40]) << 24) | (UInt32(bytes[41]) << 16)
            | (UInt32(bytes[42]) << 8) | UInt32(bytes[43])
        guard seconds > ntpToUnixOffset else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(seconds - ntpToUnixOffset))
    }
}

struct NTPResult: Equatable, Sendable {
    let serverTime: Date
    let offsetSeconds: Double
}

protocol NTPQuerying: Sendable {
    func query(server: String) async throws -> NTPResult
}

struct NTPService: NTPQuerying {
    func query(server: String) async throws -> NTPResult {
        let response = await UDPExchange.request(
            host: server, port: 123, payload: NTP.request(), timeout: 5
        )
        switch response {
        case .success(let data):
            guard let serverTime = NTP.parse(data) else {
                throw NetProbeError.noData
            }
            return NTPResult(
                serverTime: serverTime,
                offsetSeconds: serverTime.timeIntervalSinceNow
            )
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
@Observable
final class NTPViewModel {
    enum Output: Equatable {
        case idle, loading
        case success(NTPResult)
        case failure(String)
    }

    var server = "time.apple.com"
    private(set) var output: Output = .idle

    private let service: any NTPQuerying

    init(service: any NTPQuerying = NTPService()) {
        self.service = service
    }

    func query() async {
        let target = server.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { output = .idle; return }
        output = .loading
        do {
            output = .success(try await service.query(server: target))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }
}

struct NTPTool: NetworkTool {
    let id = "ntp"
    let titleKey = L10n("tool.ntp.title")
    let subtitleKey = L10n("tool.ntp.subtitle")
    let systemImage = "clock.badge.checkmark"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(NTPView()) }
}

struct NTPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = NTPViewModel()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                outputSection
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.ntp.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("ntp.input.title"), systemImage: "clock") {
            TextField("time.apple.com", text: $viewModel.server)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { Task { await viewModel.query() } }

            Button {
                Task { await viewModel.query() }
            } label: {
                Label(L10nString("ntp.action.query"), systemImage: "clock.arrow.2.circlepath")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: Spacing.md) {
                ProgressView()
                Text(L10n("common.loading")).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        case .failure(let message):
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
            }
        case .success(let result):
            SectionCard(title: L10n("ntp.section.result"), systemImage: "clock.badge.checkmark") {
                ResultRow(
                    label: L10n("ntp.result.serverTime"),
                    value: Self.formatter.string(from: result.serverTime) + " UTC"
                )
                ResultRow(
                    label: L10n("ntp.result.offset"),
                    value: String(format: "%+.3f s", result.offsetSeconds)
                )
                Text(L10n("ntp.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}
