import Foundation

/// A thin wrapper over `URLSessionWebSocketTask` (native, zero-dep) that streams
/// connection lifecycle and incoming frames back through `onEvent`.
final class WebSocketClient: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    enum Event: Sendable {
        case open
        case text(String)
        case binary(Int)
        case closed(String?)
        case error(String)
    }

    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    var onEvent: ((Event) -> Void)?

    func connect(url: URL) {
        let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.session = session
        self.task = task
        task.resume()
        receive()
    }

    func send(_ text: String) {
        task?.send(.string(text)) { [weak self] error in
            if let error { self?.onEvent?(.error(error.localizedDescription)) }
        }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        task = nil
        session = nil
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.onEvent?(.text(text))
                case .data(let data): self.onEvent?(.binary(data.count))
                @unknown default: break
                }
                self.receive()
            case .failure(let error):
                self.onEvent?(.error(error.localizedDescription))
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onEvent?(.open)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) }
        onEvent?(.closed(reasonText))
    }
}
