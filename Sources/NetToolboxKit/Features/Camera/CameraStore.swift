import Foundation
import Observation

/// Saved IP-camera profiles (name, address, ports, credentials, stream path)
/// persisted as JSON in `UserDefaults`, so a camera can be opened in one tap.
/// Stored locally on the device only.
@MainActor
@Observable
final class CameraStore {
    struct Camera: Codable, Identifiable, Equatable, Sendable {
        var id = UUID()
        var name = ""
        var host = ""
        var rtspPort = "554"
        var onvifPort = "80"
        var username = ""
        var password = ""
        /// RTSP stream path, e.g. `/stream1` or `/Streaming/Channels/101`.
        /// When empty and ONVIF is used, it is filled from `GetStreamUri`.
        var streamPath = "/"

        /// Falls back to host when no name is given.
        var displayName: String {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? host : trimmed
        }

        /// The full `rtsp://` URL the player connects to. Credentials are sent
        /// via headers (RTSP auth), not embedded in the URL, so they are not
        /// echoed in logs.
        var rtspURL: String {
            let port = rtspPort.trimmingCharacters(in: .whitespaces)
            var path = streamPath.trimmingCharacters(in: .whitespaces)
            if path.isEmpty { path = "/" }
            if !path.hasPrefix("/") { path = "/" + path }
            let portPart = (port.isEmpty || port == "554") ? "" : ":\(port)"
            return "rtsp://\(host)\(portPart)\(path)"
        }
    }

    private(set) var cameras: [Camera] = []
    private let key = "nettoolbox.cameras.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Camera].self, from: data) {
            cameras = decoded
        }
    }

    /// Inserts a new camera, or updates one with the same id.
    func save(_ camera: Camera) {
        guard !camera.host.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if let index = cameras.firstIndex(where: { $0.id == camera.id }) {
            cameras[index] = camera
        } else {
            cameras.insert(camera, at: 0)
        }
        persist()
    }

    func remove(_ camera: Camera) {
        cameras.removeAll { $0.id == camera.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cameras) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
