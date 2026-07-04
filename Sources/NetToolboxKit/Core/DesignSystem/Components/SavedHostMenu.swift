import SwiftUI

/// A compact bookmark menu placed next to a host text field: it lists the
/// user's saved hosts (tap to fill the field) and offers to save whatever is
/// currently typed. Drop it into any tool that takes a host.
struct SavedHostMenu: View {
    @Environment(SavedHostsStore.self) private var savedHosts
    @Environment(\.theme) private var theme

    @Binding var host: String

    var body: some View {
        Menu {
            if savedHosts.hosts.isEmpty {
                Text(L10n("hosts.empty.title"))
            } else {
                Section(L10nString("hosts.section.saved")) {
                    ForEach(savedHosts.hosts) { saved in
                        Button {
                            host = saved.address
                        } label: {
                            Text(saved.name == saved.address ? saved.address : "\(saved.name) · \(saved.address)")
                        }
                    }
                }
            }
            if !host.trimmingCharacters(in: .whitespaces).isEmpty {
                Divider()
                Button {
                    savedHosts.add(name: "", address: host, notes: "")
                } label: {
                    Label(L10nString("hosts.saveCurrent"), systemImage: "bookmark.fill")
                }
            }
        } label: {
            Image(systemName: "bookmark")
                .font(.body)
                .foregroundStyle(theme.accent)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .fill(theme.surfaceElevated)
                )
        }
        .accessibilityLabel(Text(L10n("hosts.saved.pick")))
    }
}
