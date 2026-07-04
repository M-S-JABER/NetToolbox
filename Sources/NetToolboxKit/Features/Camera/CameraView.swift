import SwiftUI
import Observation

@MainActor
@Observable
final class CameraViewModel {
    var selectedID: UUID?
    let session: CameraSession

    init(session: CameraSession) {
        self.session = session
    }

    func select(_ camera: CameraStore.Camera) {
        selectedID = camera.id
        session.play(camera)
    }
}

struct CameraTool: NetworkTool {
    let id = "camera"
    let titleKey = L10n("tool.camera.title")
    let subtitleKey = L10n("tool.camera.subtitle")
    let systemImage = "video"
    let category: ToolCategory = .localNetwork

    func makeView() -> AnyView { AnyView(CameraView()) }
}

struct CameraView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity
    @Environment(CameraStore.self) private var store

    @State private var editing: CameraStore.Camera?
    @State private var isFullscreen = false

    private var viewModel: CameraViewModel {
        sessions.session("camera") {
            let session = CameraSession()
            session.toolID = "camera"
            session.activity = activity
            return CameraViewModel(session: session)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.selectedID != nil, viewModel.session.camera != nil {
                    playerCard
                }
                camerasSection
                Text(L10n("camera.note"))
                    .font(AppTypography.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle(Text(L10n("tool.camera.title")))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = CameraStore.Camera()
                } label: {
                    Label(L10nString("camera.action.add"), systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { camera in
            CameraEditorSheet(camera: camera) { saved in
                store.save(saved)
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            fullscreenPlayer
        }
    }

    // MARK: - Player

    private var playerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            playerSurface
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))

            HStack(spacing: Spacing.md) {
                phaseBadge
                Spacer()
                Button {
                    isFullscreen = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .disabled(!viewModel.session.isActive)

                Button {
                    viewModel.session.retry()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    viewModel.session.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .disabled(!viewModel.session.isActive)
            }
            .font(.title3)
            .buttonStyle(.bordered)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .fill(theme.surface)
        )
    }

    private var playerSurface: some View {
        ZStack {
            Color.black
            CameraPlayerView(session: viewModel.session)
            phaseOverlay
        }
    }

    @ViewBuilder
    private var phaseOverlay: some View {
        switch viewModel.session.phase {
        case .connecting:
            VStack(spacing: Spacing.sm) {
                ProgressView().tint(.white)
                Text(L10n("camera.status.connecting"))
                    .font(AppTypography.caption)
                    .foregroundStyle(.white)
            }
        case .failed(let message):
            VStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(AppTypography.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }
        case .stopped:
            Image(systemName: "play.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.7))
        default:
            EmptyView()
        }
    }

    private var phaseBadge: some View {
        Group {
            switch viewModel.session.phase {
            case .playing:
                StatusBadge(kind: .success, text: L10n("camera.badge.live"))
            case .connecting:
                StatusBadge(kind: .info, text: L10n("camera.status.connecting"))
            case .failed:
                StatusBadge(kind: .danger, text: L10n("common.error"))
            default:
                StatusBadge(kind: .neutral, text: L10n("camera.badge.idle"))
            }
        }
    }

    private var fullscreenPlayer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            CameraPlayerView(session: viewModel.session)
                .ignoresSafeArea()
            Button {
                isFullscreen = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(Spacing.lg)
            }
        }
    }

    // MARK: - Saved cameras

    private var camerasSection: some View {
        SectionCard(title: L10n("camera.section.saved"), systemImage: "video") {
            if store.cameras.isEmpty {
                Text(L10n("camera.empty"))
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(store.cameras) { camera in
                    cameraRow(camera)
                    if camera.id != store.cameras.last?.id {
                        Divider().overlay(theme.separator)
                    }
                }
            }
        }
    }

    private func cameraRow(_ camera: CameraStore.Camera) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: viewModel.selectedID == camera.id ? "video.fill" : "video")
                .foregroundStyle(theme.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(camera.displayName)
                    .font(AppTypography.body)
                    .foregroundStyle(theme.textPrimary)
                Text(camera.rtspURL)
                    .font(AppTypography.monoCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .leftToRight)
            }
            Spacer()

            Button {
                viewModel.select(camera)
            } label: {
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    editing = camera
                } label: {
                    Label(L10nString("common.edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    if viewModel.selectedID == camera.id { viewModel.session.stop() }
                    store.remove(camera)
                } label: {
                    Label(L10nString("common.delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { viewModel.select(camera) }
    }
}

/// Add / edit form for a saved camera, presented as a sheet.
struct CameraEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var draft: CameraStore.Camera
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
}
