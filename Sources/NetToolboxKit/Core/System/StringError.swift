import Foundation

// Several engines model a failure as a human-readable message and return
// `Result<Value, String>` (e.g. BannerGrab, Redis, Memcached, SMTP, Modbus,
// TFTP, JSONFormatter, RegexTester). The standard library constrains
// `Result`'s `Failure` to `Error`, so the message type must conform. A
// `String` already carries everything these tools need, so we conform it
// directly rather than wrapping every message in a one-field error type.
extension String: Error {}
