import SwiftUI
import SwiftData

/// Subnet Calculator screen: IPv4 (full) and IPv6 (basics), auto-detected.
struct SubnetCalculatorView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SubnetCalculatorViewModel()

    @Query(
        filter: #Predicate<HistoryEntry> { $0.toolID == "subnet-calculator" },
        sort: \HistoryEntry.date,
        order: .reverse
    )
    private var history: [HistoryEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection

                switch viewModel.output {
                case .idle:
                    ContentUnavailableView(
                        "subnet.empty.title",
                        systemImage: "square.grid.3x3.square",
                        description: Text("subnet.empty.description")
                    )
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
        .navigationTitle(Text("tool.subnet.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Input

    private var inputSection: some View {
        SectionCard(title: "subnet.input.title", systemImage: "keyboard") {
            HStack(spacing: Spacing.md) {
                TextField("subnet.input.address", text: $viewModel.addressInput)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { viewModel.calculate(context: modelContext) }

                TextField(
                    viewModel.isIPv6Input ? "subnet.input.prefix" : "subnet.input.mask",
                    text: $viewModel.maskInput
                )
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.monoBody)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: 220)
                .onSubmit { viewModel.calculate(context: modelContext) }
            }

            HStack {
                Button {
                    viewModel.calculate(context: modelContext)
                } label: {
                    Label("common.calculate", systemImage: "equal.circle.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)

                Button("common.clear", role: .destructive) {
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
            SectionCard(title: "subnet.section.network", systemImage: "network") {
                HStack {
                    CopyableValue(value: result.cidrNotation, font: AppTypography.monoLarge)
                    Spacer()
                    StatusBadge(
                        kind: result.isPrivate ? .info : .success,
                        text: LocalizedStringResource(stringLiteral: result.scope.labelKey)
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

            SectionCard(title: "subnet.section.masks", systemImage: "slider.horizontal.3") {
                resultGrid([
                    ("subnet.result.subnetMask", result.subnetMask),
                    ("subnet.result.wildcardMask", result.wildcardMask),
                    ("subnet.result.cidr", "/\(result.prefix)"),
                    ("subnet.result.class", result.ipClass.rawValue),
                ])
            }

            SectionCard(title: "subnet.section.binary", systemImage: "01.square") {
                ResultRow(label: "subnet.result.addressBinary", value: result.addressBinary)
                ResultRow(label: "subnet.result.maskBinary", value: result.maskBinary)
            }
        }
    }

    // MARK: IPv6 results

    private func ipv6Results(_ result: IPv6SubnetResult) -> some View {
        SectionCard(title: "subnet.section.ipv6", systemImage: "network") {
            HStack {
                CopyableValue(value: result.cidrNotation, font: AppTypography.monoLarge)
                Spacer()
                StatusBadge(
                    kind: .info,
                    text: LocalizedStringResource(stringLiteral: result.addressType.labelKey)
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
                    label: LocalizedStringResource(stringLiteral: row.0),
                    value: row.1
                )
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        SectionCard(title: "common.error", systemImage: "exclamationmark.triangle.fill") {
            HStack(spacing: Spacing.sm) {
                StatusBadge(kind: .danger, text: "common.invalidInput")
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.danger)
            }
        }
    }

    private var historySection: some View {
        SectionCard(title: "common.history", systemImage: "clock.arrow.circlepath") {
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
