import SwiftUI
import SwiftData

/// Subnet Calculator screen: IPv4 (full) and IPv6 (basics), auto-detected.
@MainActor
struct SubnetCalculatorView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(HistoryStore.self) private var historyStore

    @State private var viewModel = SubnetCalculatorViewModel()

    // Fetched manually instead of @Query: the macro's stored key paths
    // trip Sendable warnings under strict concurrency.
    @State private var history: [HistoryEntry] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection

                switch viewModel.output {
                case .idle:
                    ContentUnavailableView {
                        Label(L10nString("subnet.empty.title"), systemImage: "square.grid.3x3.square")
                    } description: {
                        Text(L10n("subnet.empty.description"))
                    }
                    .frame(maxWidth: .infinity)
                case .failure(let message):
                    errorCard(message)
                case .ipv4(let result):
                    ipv4Results(result)
                case .ipv6(let result):
                    ipv6Results(result)
                }

                if !history.isEmpty {
                    historySection
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.subnet.title")))
        .navigationBarTitleDisplayMode(.large)
        .task { reloadHistory() }
    }

    /// Runs the calculation and refreshes the history list.
    private func calculate() {
        viewModel.calculate(context: modelContext)
        reloadHistory()
        switch viewModel.output {
        case .ipv4(let result):
            historyStore.log(toolID: "subnet-calculator", input: "\(viewModel.addressInput) \(viewModel.maskInput)", summary: result.cidrNotation)
        case .ipv6(let result):
            historyStore.log(toolID: "subnet-calculator", input: viewModel.addressInput, summary: result.cidrNotation)
        default:
            break
        }
    }

    /// Loads the five most recent calculations for this tool.
    private func reloadHistory() {
        let toolID = "subnet-calculator"
        var descriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate { $0.toolID == toolID },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        history = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: Input

    private var inputSection: some View {
        SectionCard(title: L10n("subnet.input.title"), systemImage: "keyboard") {
            HStack(spacing: Spacing.md) {
                TextField(L10nString("subnet.input.address"), text: $viewModel.addressInput)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { calculate() }

                TextField(
                    L10nString(viewModel.isIPv6Input ? "subnet.input.prefix" : "subnet.input.mask"),
                    text: $viewModel.maskInput
                )
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: 220)
                .onSubmit { calculate() }
            }

            HStack {
                Button {
                    calculate()
                } label: {
                    Label(L10nString("common.calculate"), systemImage: "equal.circle.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)

                Button(L10nString("common.clear"), role: .destructive) {
                    viewModel.clear()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(viewModel.isIPv6Input ? "IPv6" : "IPv4")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    // MARK: IPv4 results

    private func ipv4Results(_ result: IPv4SubnetResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SectionCard(title: L10n("subnet.section.network"), systemImage: "network") {
                HStack {
                    CopyableValue(value: result.cidrNotation, font: AppTypography.monoLarge)
                    Spacer()
                    StatusBadge(
                        kind: result.isPrivate ? .info : .success,
                        text: L10n(result.scope.labelKey)
                    )
                }
                Divider().overlay(theme.separator)
                resultGrid([
                    ("subnet.result.network", result.networkAddress),
                    ("subnet.result.broadcast", result.broadcastAddress),
                    ("subnet.result.firstHost", result.firstUsableHost),
                    ("subnet.result.lastHost", result.lastUsableHost),
                    ("subnet.result.usableHosts", String(result.usableHostCount)),
                    ("subnet.result.totalAddresses", String(result.totalAddressCount)),
                ])
            }

            SectionCard(title: L10n("subnet.section.masks"), systemImage: "slider.horizontal.3") {
                resultGrid([
                    ("subnet.result.subnetMask", result.subnetMask),
                    ("subnet.result.wildcardMask", result.wildcardMask),
                    ("subnet.result.cidr", "/\(result.prefix)"),
                    ("subnet.result.class", result.ipClass.rawValue),
                ])
            }

            SectionCard(title: L10n("subnet.section.binary"), systemImage: "01.square") {
                ResultRow(label: L10n("subnet.result.addressBinary"), value: result.addressBinary)
                ResultRow(label: L10n("subnet.result.maskBinary"), value: result.maskBinary)
            }
        }
    }

    // MARK: IPv6 results

    private func ipv6Results(_ result: IPv6SubnetResult) -> some View {
        SectionCard(title: L10n("subnet.section.ipv6"), systemImage: "network") {
            HStack {
                CopyableValue(value: result.cidrNotation, font: AppTypography.monoLarge)
                Spacer()
                StatusBadge(
                    kind: .info,
                    text: L10n(result.addressType.labelKey)
                )
            }
            Divider().overlay(theme.separator)
            resultGrid([
                ("subnet.result.compressed", result.compressed),
                ("subnet.result.expanded", result.expanded),
                ("subnet.result.networkPrefix", result.networkPrefix),
                ("subnet.result.prefixLength", "/\(result.prefix)"),
                ("subnet.result.totalAddresses", result.totalAddressesDescription),
            ])
        }
    }

    // MARK: Shared pieces

    private func resultGrid(_ rows: [(String, String)]) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(rows, id: \.0) { row in
                ResultRow(
                    label: L10n(row.0),
                    value: row.1
                )
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
            HStack(spacing: Spacing.sm) {
                StatusBadge(kind: .danger, text: L10n("common.invalidInput"))
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.danger)
            }
        }
    }

    private var historySection: some View {
        SectionCard(title: L10n("common.history"), systemImage: "clock.arrow.circlepath") {
            ForEach(history.prefix(5)) { entry in
                Button {
                    viewModel.load(historyInput: entry.input)
                } label: {
                    HStack {
                        Text(entry.input)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.textSecondary)
                            .environment(\.layoutDirection, .leftToRight)
                        Spacer()
                        Text(entry.summary)
                            .font(AppTypography.monoCaption)
                            .foregroundStyle(theme.mono)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
