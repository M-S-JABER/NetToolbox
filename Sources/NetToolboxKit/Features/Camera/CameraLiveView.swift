import SwiftUI
import UIKit
import AVFoundation
import CoreMedia
import Observation

/// Owns a running RTSP stream and feeds decoded frames into the display layer.
/// Kept in `ToolSessions` so a live view keeps playing when the user navigates
/// to another tool and returns.
@MainActor
@Observable
final class CameraSession {
    enum Phase: Equatable {
        case idle
        case connecting
        case playing
        case stopped
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var camera: CameraStore.Camera?
    var toolID = ""
    var activity: ActivityCenter?

    private(set) var isRecording = false
    /// Set when a recording finishes, so the UI can offer to share the file.
    var lastRecordingURL: URL?

    private var client: RTSPClient?
    private let recorder = CameraRecorder()
    private weak var displayLayer: AVSampleBufferDisplayLayer?

    var isActive: Bool {
        switch phase {
        case .connecting, .playing: return true
        default: return false
        }
    }

    /// The player view registers its layer here so frames can be enqueued.
    func attach(_ layer: AVSampleBufferDisplayLayer) {
        displayLayer = layer
    }

    func play(_ camera: CameraStore.Camera) {
        stop()
        self.camera = camera
        phase = .connecting
        activity?.start(toolID)
        displayLayer?.flushAndRemoveImage()

        let port = UInt16(camera.rtspPort.trimmingCharacters(in: .whitespaces)) ?? 554
        let client = RTSPClient(
            host: camera.host.trimmingCharacters(in: .whitespaces),
            port: port,
            username: camera.username,
            password: camera.password,
            url: camera.rtspURL
        )
        client.onStatus = { [weak self] status in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply(status) }
            }
        }
        client.onSample = { [weak self] sample in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.enqueue(sample) }
            }
        }
        self.client = client
        client.start()
    }

    func stop() {
        if recorder.isRecording {
            Task { let url = await recorder.stop(); isRecording = false; lastRecordingURL = url }
        }
        client?.stop()
        client = nil
        if isActive { phase = .stopped }
        activity?.stop(toolID)
        displayLayer?.flushAndRemoveImage()
    }

    func retry() {
        guard let camera else { return }
        play(camera)
    }

    /// Starts or stops recording the current stream to a file.
    func toggleRecording() {
        if recorder.isRecording {
            Task {
                let url = await recorder.stop()
                isRecording = false
                lastRecordingURL = url
            }
        } else if recorder.start() {
            isRecording = true
        }
    }

    private func apply(_ status: RTSPClient.Status) {
        switch status {
        case .connecting, .buffering:
            phase = .connecting
        case .playing:
            phase = .playing
        case .stopped:
            if isActive { phase = .stopped }
            activity?.stop(toolID)
        case .failed(let message):
            phase = .failed(message)
            activity?.stop(toolID)
        }
    }

    private func enqueue(_ sample: CMSampleBuffer) {
        if recorder.isRecording { recorder.append(sample) }
        guard let layer = displayLayer else { return }
        if layer.status == .failed { layer.flush() }
        layer.enqueue(sample)
        if phase == .connecting { phase = .playing }
    }
}

/// A `UIView` whose backing layer is an `AVSampleBufferDisplayLayer`, so it can
/// render decoded `CMSampleBuffer`s directly.
final class SampleBufferHostView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer? { layer as? AVSampleBufferDisplayLayer }
}

/// Bridges the display layer into SwiftUI and (re)attaches it to the session.
struct CameraPlayerView: UIViewRepresentable {
    let session: CameraSession

    func makeUIView(context: Context) -> SampleBufferHostView {
        let view = SampleBufferHostView()
        view.backgroundColor = .black
        if let layer = view.displayLayer {
            layer.videoGravity = .resizeAspect
            session.attach(layer)
        }
        return view
    }

    func updateUIView(_ uiView: SampleBufferHostView, context: Context) {
        if let layer = uiView.displayLayer {
            session.attach(layer)
        }
    }
}
