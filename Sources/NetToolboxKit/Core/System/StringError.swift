import Foundation

/// A lightweight error that carries only a human-readable message. Several
/// engines model failure as text and return `Result<Value, EngineError>`
/// (BannerGrab, Redis, Memcached, SMTP, Modbus, TFTP, JSONFormatter,
/// RegexTester). A dedicated type is used rather than conforming `String`
/// itself to `Error`, which would be a retroactive conformance to two types
/// the module doesn't own. `ExpressibleByStringLiteral` keeps literal call
/// sites terse.
struct EngineError: Error, CustomStringConvertible, ExpressibleByStringLiteral, Equatable {
    let message: String

    init(_ message: String) { self.message = message }
    init(stringLiteral value: String) { self.message = value }

    var description: String { message }
    var errorDescription: String? { message }
}
