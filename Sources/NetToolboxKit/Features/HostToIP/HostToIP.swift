import SwiftUI
import Observation
#if canImport(Darwin)
import Darwin
#endif

/// Resolves a hostname to its IPv4 and IPv6 addresses via `getaddrinfo`.
/// No permission required (public DNS resolution).
protocol HostResolving: Sendable {
    func resolve(_ host: String) async -> [String]
}

struct SystemHostResolver: HostResolving {
    func resolve(_ host: String) async -> [String] {
        await withCheckedContinuation { continuation in
            let shot = OneShot(continuation)
            DispatchQueue.global(qos: .userInitiated).async {
                shot.resume(Self.blockingResolve(host))
            }
        }
    }

    #if canImport(Darwin)
    private static func blockingResolve(_ host: String) -> [String] {
        var hints = addrinfo(
            ai_flags: 0, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM,
            ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else {
            return []
        }
        defer { freeaddrinfo(result) }

        var addresses: [String] = []
        for pointer in sequence(first: first, next: { $0.pointee.ai_next }) {
            guard let sa = pointer.pointee.ai_addr else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                sa, socklen_t(pointer.pointee.ai_addrlen),
                &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST
            ) == 0 {
                let address = String(cString: buffer)
                if !addresses.contains(address) { addresses.append(address) }
            }
        }
        return addresses
    }
    #else
    private static func blockingResolve(_ host: String) -> [String] { [] }
    #endif
}

@MainActor
@Observable
final class HostToIPViewModel {
    enum Output: Equatable {
        case idle, loading
        case success([String])
        case failure
    }

    var host = ""
    private(set) var output: Output = .idle

    private let resolver: any HostResolving

    init(resolver: any HostResolving = SystemHostResolver()) {
        self.resolver = resolver
    }

    func resolve() async {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { output = .idle; return }
        output = .loading
        let addresses = await resolver.resolve(trimmed)
        output = addresses.isEmpty ? .failure : .success(addresses)
    }
}

struct HostToIPTool: NetworkTool {
    let id = "host-to-ip"
    let titleKey = L10n("tool.host.title")
    let subtitleKey = L10n("tool.host.subtitle")
    let systemImage = "arrow.right.arrow.left"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(HostToIPView()) }
}

@MainActor
struct HostToIPView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = HostToIPViewModel()

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
        .navigationTitle(Text(L10n("tool.host.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("host.input.title"), systemImage: "arrow.right.arrow.left") {
            TextField(L10nString("host.input.placeholder"), text: $viewModel.host)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .environment(\.layoutDirection, .leftToRight)
                .onSubmit { Task { await viewModel.resolve() } }

            Button {
                Task { await viewModel.resolve() }
            } label: {
                Label(L10nString("host.action.resolve"), systemImage: "arrow.right.circle.fill")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var outputSection: some View {
        switch viewModel.output {
        case .idle:
            ContentUnavailableView {
                Label(L10nString("host.empty.title"), systemImage: "arrow.right.arrow.left")
            } description: {
                Text(L10n("host.empty.description"))
            }
        case .loading:
            HStack(spacing: Spacing.md) {
                ProgressView()
                Text(L10n("common.loading")).foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        case .failure:
            SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                Text(L10n("host.notFound")).font(AppTypography.body).foregroundStyle(theme.danger)
            }
        case .success(let addresses):
            SectionCard(title: L10n("host.section.addresses"), systemImage: "list.bullet") {
                VStack(spacing: Spacing.sm) {
                    ForEach(addresses, id: \.self) { address in
                        HStack {
                            StatusBadge(kind: address.contains(":") ? .neutral : .info,
                                        text: address.contains(":") ? "IPv6" : "IPv4")
                            Spacer()
                            CopyableValue(value: address)
                        }
                    }
                }
            }
        }
    }
}
