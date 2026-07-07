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

@MainActor
struct CameraView: View {
    @Environment(\.theme) private var theme
    @Environment(\.toolSessions) private var sessions
    @Environment(ActivityCenter.self) private var activity
    @Environment(CameraStore.self) private var store

    @State private var editing: CameraStore.Camera?
    @State private var snapshotCamera: CameraStore.Camera?
    @State private var isScanning = false
    @State private var isFullscreen = false
    @State private var isGridPresented = false
    @State private var recordingShare: ShareableFile?

    private var viewModel: CameraViewModel {
        sessions.session("camera") {
            let session = CameraSession()
            session.toolID = "camera"
            session.activity = activity
            return CameraViewModel(session: session)
        }
    }

    private var selectedCamera: CameraStore.Camera? {
        store.cameras.first { $0.id == viewModel.selectedID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.selectedID != nil, viewModel.session.camera != nil {
                    playerCard
                    if let camera = selectedCamera,
                       let ptzXAddr = camera.ptzXAddr, !ptzXAddr.isEmpty,
                       let profileToken = camera.profileToken, !profileToken.isEmpty {
                        PTZSection(camera: camera, ptzXAddr: ptzXAddr, profileToken: profileToken)
                            .id(camera.id)
                    }
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
                Menu {
                    Button {
                        editing = CameraStore.Camera()
                    } label: {
                        Label(L10nString("camera.action.add"), systemImage: "plus")
                    }
                    Button {
                        isScanning = true
                    } label: {
                        Label(L10nString("camera.action.scan"), systemImage: "dot.radiowaves.left.and.right")
                    }
                    if !store.cameras.isEmpty {
                        Button {
                            isGridPresented = true
                        } label: {
                            Label(L10nString("camera.action.grid"), systemImage: "square.grid.2x2")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editing) { camera in
            CameraEditorSheet(camera: camera) { saved in
                store.save(saved)
            }
        }
        .sheet(item: $snapshotCamera) { camera in
            SnapshotSheet(camera: camera)
        }
        .sheet(isPresented: $isScanning) {
            CameraScanSheet { ip in
                var draft = CameraStore.Camera()
                draft.host = ip
                editing = draft
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            fullscreenPlayer
        }
        .fullScreenCover(isPresented: $isGridPresented) {
            CameraGridView()
        }
        .sheet(item: $recordingShare) { item in
            RecordingShareSheet(url: item.url)
        }
        .onChange(of: viewModel.session.lastRecordingURL) { _, url in
            if let url { recordingShare = ShareableFile(url: url) }
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
                    viewModel.session.toggleRecording()
                } label: {
                    Image(systemName: viewModel.session.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundStyle(viewModel.session.isRecording ? Color.red : theme.accent)
                }
                .disabled(!viewModel.session.isActive)
                if selectedCamera?.snapshotURI?.isEmpty == false {
                    Button {
                        snapshotCamera = selectedCamera
                    } label: {
                        Image(systemName: "camera")
                    }
                }
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
            if viewModel.session.isRecording {
                HStack(spacing: Spacing.xs) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Text(L10n("camera.badge.rec"))
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
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
                if camera.snapshotURI?.isEmpty == false {
                    Button {
                        snapshotCamera = camera
                    } label: {
                        Label(L10nString("camera.action.snapshot"), systemImage: "camera")
                    }
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
