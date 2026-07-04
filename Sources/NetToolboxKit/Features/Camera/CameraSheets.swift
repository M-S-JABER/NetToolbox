import SwiftUI
import UIKit

/// Identifiable wrapper so a recorded file URL can drive a `.sheet(item:)`.
struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// Presents the finished recording with a share/save action.
struct RecordingShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let url: URL

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(theme.success)
                Text(L10n("camera.record.title"))
                    .font(AppTypography.headline)
                    .foregroundStyle(theme.textPrimary)
                Text(url.lastPathComponent)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .environment(\.layoutDirection, .leftToRight)
                ShareLink(item: url) {
                    Label(L10nString("common.share"), systemImage: "square.and.arrow.up")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Text(L10n("camera.record.hint"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background)
            .navigationTitle(Text(L10n("camera.record.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10nString("common.done")) { dismiss() }
                }
            }
        }
    }
}

/// Add / edit form for a saved camera, with optional ONVIF auto-configuration.
struct CameraEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var draft: CameraStore.Camera
    @State private var isProbing = false
    @State private var probeError: String?
    @State private var discovery: ONVIFDiscovery?
    @State private var selectedProfileToken: String?
    private let onSave: (CameraStore.Camera) -> Void

    init(camera: CameraStore.Camera, onSave: @escaping (CameraStore.Camera) -> Void) {
        _draft = State(initialValue: camera)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10nString("camera.form.identity")) {
                    TextField(L10nString("camera.form.name"), text: $draft.name)
                    HStack {
                        TextField(L10nString("camera.form.host"), text: $draft.host)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .environment(\.layoutDirection, .leftToRight)
                        SavedHostMenu(host: $draft.host)
                    }
                }
                Section(L10nString("camera.form.stream")) {
                    TextField(L10nString("camera.form.rtspPort"), text: $draft.rtspPort)
                        .keyboardType(.numberPad)
                        .environment(\.layoutDirection, .leftToRight)
                    TextField(L10nString("camera.form.path"), text: $draft.streamPath)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                    TextField(L10nString("camera.form.onvifPort"), text: $draft.onvifPort)
                        .keyboardType(.numberPad)
                        .environment(\.layoutDirection, .leftToRight)
                }
                Section(L10nString("camera.form.credentials")) {
                    TextField(L10nString("camera.form.username"), text: $draft.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .environment(\.layoutDirection, .leftToRight)
                    SecureField(L10nString("camera.form.password"), text: $draft.password)
                        .environment(\.layoutDirection, .leftToRight)
                }
                onvifSection
                Section {
                    Text(L10n("camera.form.hint"))
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .navigationTitle(Text(L10n("camera.form.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nString("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10nString("common.save")) {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.host.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var onvifSection: some View {
        Section(L10nString("onvif.section")) {
            Button {
                probe()
            } label: {
                Label(L10nString("onvif.action.fetch"), systemImage: "sparkle.magnifyingglass")
            }
            .disabled(isProbing || draft.host.trimmingCharacters(in: .whitespaces).isEmpty)

            if isProbing {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(L10n("onvif.probing")).foregroundStyle(theme.textSecondary)
                }
            }
            if let probeError {
                Text(probeError)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.danger)
            }
            if let discovery {
                if !discovery.deviceInfo.isEmpty {
                    deviceInfoRow(L10n("onvif.device.manufacturer"), discovery.deviceInfo.manufacturer)
                    deviceInfoRow(L10n("onvif.device.model"), discovery.deviceInfo.model)
                    deviceInfoRow(L10n("onvif.device.firmware"), discovery.deviceInfo.firmware)
                }
                if !discovery.profiles.isEmpty {
                    Picker(L10nString("onvif.profile"), selection: $selectedProfileToken) {
                        ForEach(discovery.profiles) { profile in
                            Text(profileLabel(profile)).tag(Optional(profile.token))
                        }
                    }
                    .onChange(of: selectedProfileToken) { _, token in applyProfile(token) }
                }
            }
        }
    }

    private func deviceInfoRow(_ label: LocalizedStringResource, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(AppTypography.footnote)
    }

    private func profileLabel(_ profile: ONVIFProfile) -> String {
        if let resolution = profile.resolutionText {
            return "\(profile.name) · \(resolution)"
        }
        return profile.name
    }

    private func probe() {
        isProbing = true
        probeError = nil
        let client = ONVIFClient(
            host: draft.host.trimmingCharacters(in: .whitespaces),
            port: UInt16(draft.onvifPort.trimmingCharacters(in: .whitespaces)) ?? 80,
            username: draft.username,
            password: draft.password
        )
        Task { @MainActor in
            do {
                let result = try await client.discover()
                discovery = result
                draft.ptzXAddr = result.ptzXAddr
                if let first = result.profiles.first {
                    selectedProfileToken = first.token
                    applyProfile(first.token)
                }
            } catch {
                probeError = error.localizedDescription
            }
            isProbing = false
        }
    }

    private func applyProfile(_ token: String?) {
        guard let token, let profile = discovery?.profiles.first(where: { $0.token == token }) else { return }
        draft.profileToken = token
        draft.snapshotURI = profile.snapshotURI
        guard let uri = profile.streamURI, let components = URLComponents(string: uri) else { return }
        if let port = components.port { draft.rtspPort = String(port) }
        var path = components.path
        if let query = components.query, !query.isEmpty { path += "?\(query)" }
        if !path.isEmpty { draft.streamPath = path }
    }
}

/// Fetches and shows a still snapshot for a camera via its ONVIF snapshot URI.
struct SnapshotSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let camera: CameraStore.Camera

    @State private var image: UIImage?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else if isLoading {
                    VStack(spacing: Spacing.sm) {
                        ProgressView()
                        Text(L10n("camera.snapshot.loading")).foregroundStyle(theme.textSecondary)
                    }
                } else {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundStyle(theme.textSecondary)
                        Text(errorMessage ?? L10nString("camera.snapshot.failed"))
                            .font(AppTypography.footnote)
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xl)
                    }
                }
            }
            .navigationTitle(Text(L10n("camera.snapshot.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10nString("common.done")) { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let uri = camera.snapshotURI, !uri.isEmpty else {
            isLoading = false
            return
        }
        let fetcher = SnapshotFetcher(username: camera.username, password: camera.password)
        do {
            let data = try await fetcher.fetch(uri)
            if let decoded = UIImage(data: data) {
                image = decoded
            } else {
                errorMessage = L10nString("camera.snapshot.failed")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

/// Scans the local subnet for hosts with the RTSP port open and lets the user
/// turn one into a new camera.
struct CameraScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let onPick: (String) -> Void

    @State private var base = ""
    @State private var results: [String] = []
    @State private var isScanning = false
    @State private var didScan = false

    private let scanner = CameraScanner()

    var body: some View {
        NavigationStack {
            Form {
                Section(L10nString("camera.scan.title")) {
                    TextField(L10nString("camera.scan.base"), text: $base)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.numbersAndPunctuation)
                        .environment(\.layoutDirection, .leftToRight)
                    Button {
                        Task { @MainActor in await scan() }
                    } label: {
                        if isScanning {
                            HStack(spacing: Spacing.sm) {
                                ProgressView()
                                Text(L10n("camera.scan.scanning"))
                            }
                        } else {
                            Label(L10nString("camera.scan.start"), systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                    .disabled(isScanning || base.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if !results.isEmpty {
                    Section(L10nString("camera.scan.found")) {
                        ForEach(results, id: \.self) { ip in
                            Button {
                                onPick(ip)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "video.badge.plus").foregroundStyle(theme.accent)
                                    Text(ip)
                                        .font(AppTypography.monoBody)
                                        .foregroundStyle(theme.textPrimary)
                                        .environment(\.layoutDirection, .leftToRight)
                                    Spacer()
                                }
                            }
                        }
                    }
                } else if didScan, !isScanning {
                    Section {
                        Text(L10n("camera.scan.empty"))
                            .font(AppTypography.footnote)
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Section {
                    Text(L10n("camera.scan.note"))
                        .font(AppTypography.footnote)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .navigationTitle(Text(L10n("camera.action.scan")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nString("common.cancel")) { dismiss() }
                }
            }
            .onAppear {
                if base.isEmpty, let derived = scanner.subnetBase() { base = derived }
            }
        }
    }

    private func scan() async {
        isScanning = true
        didScan = true
        results = []
        let prefix = base.trimmingCharacters(in: .whitespaces)
        let normalized = prefix.hasSuffix(".") ? prefix : prefix + "."
        results = await scanner.scan(base: normalized)
        isScanning = false
    }
}
