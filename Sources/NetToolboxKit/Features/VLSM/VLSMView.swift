import SwiftUI
import Observation

@MainActor
@Observable
final class VLSMViewModel {
    var baseCIDR = "192.168.1.0/24"
    var requests: [VLSMRequest] = [
        VLSMRequest(name: "Sales", hosts: 50),
        VLSMRequest(name: "IT", hosts: 20),
    ]
    private(set) var allocations: [VLSMAllocation] = []
    private(set) var errorMessage: String?

    func addRequest() {
        requests.append(VLSMRequest(name: "", hosts: 10))
    }

    func remove(_ request: VLSMRequest) {
        requests.removeAll { $0.id == request.id }
    }

    func calculate() {
        errorMessage = nil
        do {
            allocations = try VLSMEngine.allocate(baseCIDR: baseCIDR, requests: requests)
        } catch {
            allocations = []
            errorMessage = error.localizedDescription
        }
    }
}

struct VLSMTool: NetworkTool {
    let id = "vlsm"
    let titleKey = L10n("tool.vlsm.title")
    let subtitleKey = L10n("tool.vlsm.subtitle")
    let systemImage = "square.stack.3d.up"
    let category: ToolCategory = .calculators

    func makeView() -> AnyView { AnyView(VLSMView()) }
}

@MainActor
struct VLSMView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = VLSMViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let message = viewModel.errorMessage {
                    SectionCard(title: L10n("common.error"), systemImage: "exclamationmark.triangle.fill") {
                        Text(message).font(AppTypography.body).foregroundStyle(theme.danger)
                    }
                }
                if !viewModel.allocations.isEmpty {
                    resultsSection
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.vlsm.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        SectionCard(title: L10n("vlsm.input.title"), systemImage: "square.stack.3d.up") {
            HStack {
                Text(L10n("vlsm.base"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                TextField("192.168.1.0/24", text: $viewModel.baseCIDR)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Divider().overlay(theme.separator)

            ForEach($viewModel.requests) { $request in
                HStack(spacing: Spacing.sm) {
                    TextField(L10nString("vlsm.name"), text: $request.name)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.body)
                    TextField(L10nString("vlsm.hosts"), value: $request.hosts, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(AppTypography.monoBody)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 90)
                        .environment(\.layoutDirection, .leftToRight)
                    Button {
                        viewModel.remove(request)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(theme.danger)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Button {
                    viewModel.addRequest()
                } label: {
                    Label(L10nString("vlsm.add"), systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                Spacer()
                Button {
                    viewModel.calculate()
                } label: {
                    Label(L10nString("common.calculate"), systemImage: "equal.circle.fill")
                        .font(AppTypography.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var resultsSection: some View {
        SectionCard(title: L10n("vlsm.section.result"), systemImage: "list.bullet.rectangle") {
            VStack(spacing: Spacing.md) {
                ForEach(viewModel.allocations) { allocation in
                    allocationRow(allocation)
                }
            }
        }
    }

    private func allocationRow(_ allocation: VLSMAllocation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(allocation.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                CopyableValue(value: allocation.cidr, font: AppTypography.monoBody)
            }
            HStack(spacing: Spacing.lg) {
                Text(allocation.mask)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
                Text("\(allocation.firstHost) – \(allocation.lastHost)")
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.mono)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
                StatusBadge(
                    kind: .info,
                    text: LocalizedStringResource(stringLiteral: "\(allocation.requestedHosts)/\(allocation.usableHosts)")
                )
            }
            Divider().overlay(theme.separator)
        }
    }
}
