import Foundation

/// Pure password generation and strength estimation. Character-set maths
/// and entropy are unit-tested; the draw uses the system CSPRNG.
enum PasswordGenerator {
    struct Options: Equatable, Sendable {
        var length: Int = 16
        var lowercase = true
        var uppercase = true
        var digits = true
        var symbols = true
    }

    static let lowercaseSet = "abcdefghijklmnopqrstuvwxyz"
    static let uppercaseSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    static let digitSet = "0123456789"
    static let symbolSet = "!@#$%^&*()-_=+[]{};:,.?/"

    /// The pool of characters enabled by `options`.
    static func pool(for options: Options) -> [Character] {
        var pool = ""
        if options.lowercase { pool += lowercaseSet }
        if options.uppercase { pool += uppercaseSet }
        if options.digits { pool += digitSet }
        if options.symbols { pool += symbolSet }
        return Array(pool)
    }

    /// Estimated entropy in bits: length × log2(poolSize).
    static func entropyBits(for options: Options) -> Double {
        let size = pool(for: options).count
        guard size > 1, options.length > 0 else { return 0 }
        return Double(options.length) * log2(Double(size))
    }

    enum Strength: String, Sendable {
        case weak, fair, strong, excellent
        var labelKey: String { "password.strength.\(rawValue)" }
    }

    static func strength(bits: Double) -> Strength {
        switch bits {
        case ..<40: .weak
        case 40..<70: .fair
        case 70..<100: .strong
        default: .excellent
        }
    }

    /// Draws a password from the enabled pool using the system CSPRNG.
    static func generate(_ options: Options) -> String {
        let pool = pool(for: options)
        guard !pool.isEmpty, options.length > 0 else { return "" }
        var generator = SystemRandomNumberGenerator()
        var result = ""
        for _ in 0..<options.length {
            result.append(pool[Int.random(in: 0..<pool.count, using: &generator)])
        }
        return result
    }
}
