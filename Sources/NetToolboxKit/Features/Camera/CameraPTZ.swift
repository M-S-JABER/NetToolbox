import SwiftUI
import Observation

/// Drives ONVIF PTZ for one camera: continuous moves while a control is held,
/// stop on release, and preset recall. Aligns its WS-Security timestamp to the
/// camera clock once on `prepare()`.
@MainActor
@Observable
final class PTZController {
    private var client: ONVIFClient
    private let ptzXAddr: String
    private let profileToken: String

    private(set) var presets: [ONVIFPreset] = []
    private(set) var ready = false
    var errorMessage: String?

    init(camera: CameraStore.Camera, ptzXAddr: String, profileToken: String) {
        self.client = ONVIFClient(
            host: camera.host.trimmingCharacters(in: .whitespaces),
            port: UInt16(camera.onvifPort.trimmingCharacters(in: .whitespaces)) ?? 80,
            username: camera.username,
            password: camera.password
        )
        self.ptzXAddr = ptzXAddr
        self.profileToken = profileToken
    }

    func prepare() async {
        client.clockOffset = await client.measureClockOffset()
        ready = true
        presets = (try? await client.getPresets(profileToken: profileToken, ptzXAddr: ptzXAddr)) ?? []
    }

    func move(pan: Double, tilt: Double, zoom: Double) {
        let client = client
        let token = profileToken
        let address = ptzXAddr
        Task {
            do {
                try await client.continuousMove(profileToken: token, ptzXAddr: address, pan: pan, tilt: tilt, zoom: zoom)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stop() {
        let client = client
        let token = profileToken
        let address = ptzXAddr
        Task { try? await client.stopMove(profileToken: token, ptzXAddr: address) }
    }

    func goto(_ preset: ONVIFPreset) {
        let client = client
        let token = profileToken
        let address = ptzXAddr
        Task {
            do {
                try await client.gotoPreset(profileToken: token, ptzXAddr: address, presetToken: preset.token)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// The PTZ card shown under the live view for cameras that expose PTZ.
struct PTZSection: View {
    @Environment(\.theme) private var theme

    @State private var controller: PTZController
    private let speed = 0.6

    init(camera: CameraStore.Camera, ptzXAddr: String, profileToken: String) {
        _controller = State(initialValue: PTZController(camera: camera, ptzXAddr: ptzXAddr, profileToken: profileToken))
    }

    var body: some View {
        SectionCard(title: L10n("camera.ptz.title"), systemImage: "dpad") {
            HStack(alignment: .center, spacing: Spacing.xl) {
                directionPad
                Spacer()
                zoomColumn
            }
            .frame(maxWidth: .infinity)

            if !controller.presets.isEmpty {
                Divider().overlay(theme.separator)
                presetsRow
            }

            if let message = controller.errorMessage {
                Text(message)
                    .font(AppTypography.footnote)
                    .foregroundStyle(theme.danger)
            }
        }
        .task { await controller.prepare() }
    }

    private var directionPad: some View {
        VStack(spacing: Spacing.sm) {
            holdButton("chevron.up", label: L10n("camera.ptz.up"), pan: 0, tilt: speed, zoom: 0)
            HStack(spacing: Spacing.sm) {
                holdButton("chevron.left", label: L10n("camera.ptz.left"), pan: -speed, tilt: 0, zoom: 0)
                Image(systemName: "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 56, height: 56)
                holdButton("chevron.right", label: L10n("camera.ptz.right"), pan: speed, tilt: 0, zoom: 0)
            }
            holdButton("chevron.down", label: L10n("camera.ptz.down"), pan: 0, tilt: -speed, zoom: 0)
        }
    }

    private var zoomColumn: some View {
        VStack(spacing: Spacing.sm) {
            holdButton("plus.magnifyingglass", label: L10n("camera.ptz.zoomIn"), pan: 0, tilt: 0, zoom: speed)
            holdButton("minus.magnifyingglass", label: L10n("camera.ptz.zoomOut"), pan: 0, tilt: 0, zoom: -speed)
        }
    }

    private var presetsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n("camera.ptz.presets"))
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(controller.presets) { preset in
                        Button {
                            controller.goto(preset)
                        } label: {
                            Text(preset.name)
                                .font(AppTypography.footnote)
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func holdButton(_ systemImage: String, label: LocalizedStringResource, pan: Double, tilt: Double, zoom: Double) -> some View {
        PTZHoldButton(systemImage: systemImage, label: label) {
            controller.move(pan: pan, tilt: tilt, zoom: zoom)
        } onRelease: {
            controller.stop()
        }
    }
}

/// A round button that fires `onPress` when first touched and `onRelease` when
/// the finger lifts — the press-and-hold interaction PTZ needs.
struct PTZHoldButton: View {
    @Environment(\.theme) private var theme

    let systemImage: String
    let label: LocalizedStringResource
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressing = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(isPressing ? Color.white : theme.accent)
            .frame(width: 56, height: 56)
            .background(
                Circle().fill(isPressing ? theme.accent : theme.surfaceElevated)
            )
            .accessibilityLabel(Text(label))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            isPressing = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressing = false
                        onRelease()
                    }
            )
    }
}
