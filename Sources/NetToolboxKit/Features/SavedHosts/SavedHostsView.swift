import SwiftUI

struct SavedHostsTool: NetworkTool {
    let id = "saved-hosts"
    let titleKey = L10n("tool.hosts.title")
    let subtitleKey = L10n("tool.hosts.subtitle")
    let systemImage = "bookmark"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(SavedHostsView()) }
}

struct SavedHostsView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var store

    @State private var name = ""
    @State private var address = ""
    @State private var notes = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                addCard
                if store.hosts.isEmpty {
                    ContentUnavailableView {
                        Label(L10nString("hosts.empty.title"), systemImage: "bookmark")
                    } description: {
                        Text(L10n("hosts.empty.description"))
                    }
                    .padding(.top, Spacing.xl)
                } else {
                    listCard
                }
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.hosts.title")))
        .navigationBarTitleDisplayMode(.large)
    }

    private var addCard: some View {
        SectionCard(title: L10n("hosts.add.title"), systemImage: "plus.circle") {
            TextField(L10nString("hosts.name"), text: $name)
                .textFieldStyle(.roundedBorder).font(AppTypography.body)
                .autocorrectionDisabled()
            TextField(L10nString("hosts.address"), text: $address)
                .textFieldStyle(.roundedBorder).font(AppTypography.monoBody)
                .keyboardType(.URL).autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .environment(\.layoutDirection, .leftToRight)
            TextField(L10nString("hosts.notes"), text: $notes)
                .textFieldStyle(.roundedBorder).font(AppTypography.body)
                .autocorrectionDisabled()

            Button {
                store.add(name: name, address: address, notes: notes)
                name = ""; address = ""; notes = ""
            } label: {
                Label(L10nString("hosts.save"), systemImage: "bookmark.fill")
                    .font(AppTypography.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var listCard: some View {
        SectionCard(title: L10n("hosts.section.saved"), systemImage: "list.bullet") {
            VStack(spacing: Spacing.sm) {
                ForEach(store.hosts) { host in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(host.name)
                                .font(AppTypography.headline)
                                .foregroundStyle(theme.textPrimary)
                            if !host.notes.isEmpty {
                                Text(host.notes)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        Spacer()
                        CopyableValue(value: host.address)
                        Button {
                            withAnimation { store.remove(host) }
                        } label: {
                            Image(systemName: "trash").foregroundStyle(theme.danger)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }
        }
    }
}
