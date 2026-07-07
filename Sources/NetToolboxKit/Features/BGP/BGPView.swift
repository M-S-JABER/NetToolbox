import SwiftUI
import Observation

// MARK: - ASN Info

@MainActor
@Observable
final class ASNInfoViewModel {
    var query = "AS15169"
    private(set) var result: ASNResult?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service = BGPService()

    func lookup() async {
        let value = query.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        result = nil
        do {
            result = try await service.lookupASN(value)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct ASNInfoTool: NetworkTool {
    let id = "bgp-asn"
    let titleKey = L10n("tool.bgpasn.title")
    let subtitleKey = L10n("tool.bgpasn.subtitle")
    let systemImage = "number.circle"
    let category: ToolCategory = .bgp

    func makeView() -> AnyView { AnyView(ASNInfoView()) }
}

@MainActor
struct ASNInfoView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = ASNInfoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let result = viewModel.result {
                    overviewSection(result)
                    if !result.prefixes.isEmpty { prefixesSection(result) }
                }
                Text(L10n("bgp.note.asn"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.bgpasn.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("bgp.section.query"), systemImage: "magnifyingglass") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("bgp.asn.input"), text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await viewModel.lookup() } }
                Button {
                    Task { await viewModel.lookup() }
                } label: {
                    Label(L10nString("bgp.action.lookup"), systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func overviewSection(_ result: ASNResult) -> some View {
        SectionCard(title: L10n("bgp.section.overview"), systemImage: "info.circle") {
            ResultRow(label: L10n("bgp.asn"), value: result.asn)
            ResultRow(label: L10n("bgp.holder"), value: result.holder, isMonospaced: false)
            ResultRow(label: L10n("bgp.type"), value: result.type, isMonospaced: false)
            ResultRow(label: L10n("bgp.neighbours"), value: String(result.neighbours))
            ResultRow(label: L10n("bgp.prefixCount"), value: String(result.prefixes.count))
        }
    }

    private func prefixesSection(_ result: ASNResult) -> some View {
        SectionCard(title: L10n("bgp.section.prefixes"), systemImage: "list.bullet") {
            ForEach(result.prefixes.prefix(200), id: \.self) { prefix in
                Text(prefix)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.mono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}

// MARK: - IP → BGP

@MainActor
@Observable
final class IPBGPViewModel {
    var query = "8.8.8.8"
    private(set) var result: IPBGPResult?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service = BGPService()

    func lookup() async {
        let value = query.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        result = nil
        do {
            result = try await service.lookupIP(value)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct IPBGPTool: NetworkTool {
    let id = "bgp-ip"
    let titleKey = L10n("tool.bgpip.title")
    let subtitleKey = L10n("tool.bgpip.subtitle")
    let systemImage = "point.topleft.down.curvedto.point.bottomright.up"
    let category: ToolCategory = .bgp

    func makeView() -> AnyView { AnyView(IPBGPView()) }
}

@MainActor
struct IPBGPView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var savedHosts
    @State private var viewModel = IPBGPViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                inputSection
                if let result = viewModel.result {
                    resultSection(result)
                }
                Text(L10n("bgp.note.ip"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.bgpip.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var inputSection: some View {
        @Bindable var viewModel = viewModel
        return SectionCard(title: L10n("bgp.section.query"), systemImage: "magnifyingglass") {
            HStack(spacing: Spacing.sm) {
                TextField(L10nString("bgp.ip.input"), text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTypography.monoBody)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                    .environment(\.layoutDirection, .leftToRight)
                    .onSubmit { Task { await viewModel.lookup() } }
                SavedHostMenu(host: $viewModel.query)
                Button {
                    Task { await viewModel.lookup() }
                } label: {
                    Label(L10nString("bgp.action.lookup"), systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Text(message).font(AppTypography.footnote).foregroundStyle(theme.danger)
            }
        }
    }

    private func resultSection(_ result: IPBGPResult) -> some View {
        SectionCard(title: L10n("bgp.section.origins"), systemImage: "arrow.triangle.branch") {
            ResultRow(label: L10n("bgp.query"), value: result.query)
            ResultRow(label: L10n("bgp.prefix"), value: result.prefix)
            Divider().overlay(theme.separator)
            if result.origins.isEmpty {
                Text(L10n("bgp.empty"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(result.origins) { origin in
                    HStack(spacing: Spacing.md) {
                        Text("AS\(origin.asn)")
                            .font(AppTypography.monoBody)
                            .foregroundStyle(theme.mono)
                            .environment(\.layoutDirection, .leftToRight)
                        Text(origin.holder)
                            .font(AppTypography.footnote)
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
        }
    }
}
