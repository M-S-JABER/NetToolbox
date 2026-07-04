import SwiftUI
import UniformTypeIdentifiers

/// A portable snapshot of the user's on-device data. Versioned so future
/// fields can be added without breaking older backups.
struct AppBackup: Codable {
    var version = 1
    var exportedAt: Double = 0
    var hosts: [SavedHostsStore.Host] = []
    var sshProfiles: [SSHProfilesStore.Profile] = []
    var cameras: [CameraStore.Camera] = []
    var speedHistory: [SpeedHistoryStore.Record] = []
}

struct BackupTool: NetworkTool {
    let id = "backup"
    let titleKey = L10n("tool.backup.title")
    let subtitleKey = L10n("tool.backup.subtitle")
    let systemImage = "arrow.up.arrow.down.circle"
    let category: ToolCategory = .diagnostics

    func makeView() -> AnyView { AnyView(BackupView()) }
}

struct BackupView: View {
    @Environment(\.theme) private var theme
    @Environment(SavedHostsStore.self) private var hosts
    @Environment(SSHProfilesStore.self) private var sshProfiles
    @Environment(CameraStore.self) private var cameras
    @Environment(SpeedHistoryStore.self) private var speedHistory

    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var message: BackupMessage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                summarySection
                exportSection
                importSection
                if let message {
                    messageView(message)
                }
                Text(L10n("backup.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.backup.title")))
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        SectionCard(title: L10n("backup.section.contents"), systemImage: "shippingbox") {
            countRow(L10n("backup.item.hosts"), hosts.hosts.count)
            countRow(L10n("backup.item.ssh"), sshProfiles.profiles.count)
            countRow(L10n("backup.item.cameras"), cameras.cameras.count)
            countRow(L10n("backup.item.speed"), speedHistory.records.count)
        }
    }

    private func countRow(_ label: LocalizedStringResource, _ count: Int) -> some View {
        HStack {
            Text(label).font(AppTypography.body).foregroundStyle(theme.textPrimary)
            Spacer()
            Text("\(count)")
                .font(AppTypography.monoBody)
                .foregroundStyle(theme.mono)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        SectionCard(title: L10n("backup.section.export"), systemImage: "square.and.arrow.up") {
            Button {
                prepareExport()
            } label: {
                Label(L10nString("backup.action.export"), systemImage: "square.and.arrow.up")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let exportURL {
                ShareLink(item: exportURL) {
                    Label(L10nString("common.share"), systemImage: "paperplane")
                        .font(AppTypography.footnote)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Import

    private var importSection: some View {
        SectionCard(title: L10n("backup.section.import"), systemImage: "square.and.arrow.down") {
            Button {
                isImporting = true
            } label: {
                Label(L10nString("backup.action.import"), systemImage: "square.and.arrow.down")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(L10n("backup.import.warning"))
                .font(AppTypography.footnote)
                .foregroundStyle(theme.warning)
        }
    }

    @ViewBuilder
    private func messageView(_ message: BackupMessage) -> some View {
        SectionCard(title: message.isError ? L10n("common.error") : L10n("backup.section.done"), systemImage: message.isError ? "exclamationmark.triangle" : "checkmark.circle") {
            Text(message.text)
                .font(AppTypography.body)
                .foregroundStyle(message.isError ? theme.danger : theme.textPrimary)
        }
    }

    // MARK: - Actions

    private func prepareExport() {
        var backup = AppBackup()
        backup.exportedAt = Date().timeIntervalSince1970
        backup.hosts = hosts.hosts
        backup.sshProfiles = sshProfiles.profiles
        backup.cameras = cameras.cameras
        backup.speedHistory = speedHistory.records

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(backup),
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            message = BackupMessage(text: L10nString("backup.error.export"), isError: true)
            return
        }
        let url = directory.appendingPathComponent("NetToolbox-backup.json")
        do {
            try data.write(to: url, options: .atomic)
            exportURL = url
            message = nil
        } catch {
            message = BackupMessage(text: error.localizedDescription, isError: true)
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            message = BackupMessage(text: error.localizedDescription, isError: true)
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url),
                  let backup = try? JSONDecoder().decode(AppBackup.self, from: data) else {
                message = BackupMessage(text: L10nString("backup.error.import"), isError: true)
                return
            }
            hosts.replaceAll(backup.hosts)
            sshProfiles.replaceAll(backup.sshProfiles)
            cameras.replaceAll(backup.cameras)
            speedHistory.replaceAll(backup.speedHistory)
            message = BackupMessage(text: L10nString("backup.import.done"), isError: false)
        }
    }
}

private struct BackupMessage {
    let text: String
    let isError: Bool
}
