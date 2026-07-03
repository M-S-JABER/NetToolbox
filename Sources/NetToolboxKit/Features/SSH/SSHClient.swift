import Foundation
import Citadel
import NIOCore

/// Runs a single command over SSH and returns its combined output.
/// Backed by Citadel (SwiftNIO SSH) behind a protocol so it stays mockable.
protocol SSHRunning: Sendable {
    func execute(
        host: String, port: Int, username: String, password: String, command: String
    ) async throws -> String
}

struct CitadelSSHRunner: SSHRunning {
    func execute(
        host: String, port: Int, username: String, password: String, command: String
    ) async throws -> String {
        let client = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: .passwordBased(username: username, password: password),
            hostKeyValidator: .acceptAnything(),
            reconnect: .never
        )
        do {
            let buffer = try await client.executeCommand(command)
            let output = String(buffer: buffer)
            try? await client.close()
            return output
        } catch {
            try? await client.close()
            throw error
        }
    }
}
