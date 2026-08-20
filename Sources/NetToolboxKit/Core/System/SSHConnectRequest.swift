import Foundation
import Observation

/// A cross-tool request to open the SSH tool pre-filled with a host — used by
/// the MikroTik tool's "open interactive CLI over SSH" action, since RouterOS's
/// real CLI is exposed over SSH (port 22), not the structured API. Injected
/// app-wide: the writer calls `request(...)`, `RootView` navigates to the SSH
/// tool, and `SSHView` applies the fields.
@MainActor
@Observable
final class SSHConnectRequest {
    private(set) var host = ""
    private(set) var port = "22"
    private(set) var username = ""
    /// Increments on each request; observers apply when it changes.
    private(set) var token = 0

    func request(host: String, port: String = "22", username: String = "") {
        self.host = host.trimmingCharacters(in: .whitespaces)
        self.port = port
        self.username = username.trimmingCharacters(in: .whitespaces)
        token += 1
    }
}
