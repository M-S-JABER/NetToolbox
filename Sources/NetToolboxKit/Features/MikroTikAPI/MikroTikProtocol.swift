import Foundation

/// Errors from the MikroTik RouterOS API client.
enum MikroTikError: LocalizedError, Equatable {
    case connectionFailed(String)
    case loginFailed(String)
    case protocolError

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): message
        case .loginFailed(let message): message
        case .protocolError: String(localized: "error.mikrotik.protocol", bundle: .module)
        }
    }
}

/// Pure encoder/decoder for the RouterOS API wire framing.
///
/// The API sends length-prefixed "words"; a "sentence" is a run of words
/// ended by a zero-length word. The length prefix uses a variable number
/// of bytes depending on magnitude. This type is fully unit-tested; the
/// transport is `TCPConnection`.
enum MikroTikProtocol {

    /// Encodes a word length using RouterOS's variable-length scheme.
    static func encodeLength(_ length: Int) -> [UInt8] {
        switch length {
        case ..<0x80:
            return [UInt8(length)]
        case ..<0x4000:
            let value = length | 0x8000
            return [UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        case ..<0x20_0000:
            let value = length | 0xC0_0000
            return [UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        case ..<0x1000_0000:
            let value = length | 0xE000_0000
            return [
                UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF),
            ]
        default:
            return [
                0xF0,
                UInt8((length >> 24) & 0xFF), UInt8((length >> 16) & 0xFF),
                UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF),
            ]
        }
    }

    /// Encodes a single word (length prefix + UTF-8 bytes).
    static func encodeWord(_ word: String) -> [UInt8] {
        let bytes = Array(word.utf8)
        return encodeLength(bytes.count) + bytes
    }

    /// Encodes a full sentence (words + terminating zero-length word).
    static func encodeSentence(_ words: [String]) -> Data {
        var data: [UInt8] = []
        for word in words {
            data.append(contentsOf: encodeWord(word))
        }
        data.append(contentsOf: encodeLength(0))
        return Data(data)
    }

    /// Decodes a length prefix starting at `offset`.
    /// Returns the length and the number of prefix bytes consumed.
    static func decodeLength(_ bytes: [UInt8], at offset: Int) -> (length: Int, consumed: Int)? {
        guard offset < bytes.count else { return nil }
        let first = bytes[offset]

        if first & 0x80 == 0x00 {
            return (Int(first), 1)
        }
        if first & 0xC0 == 0x80 {
            guard offset + 1 < bytes.count else { return nil }
            let length = (Int(first & 0x3F) << 8) | Int(bytes[offset + 1])
            return (length, 2)
        }
        if first & 0xE0 == 0xC0 {
            guard offset + 2 < bytes.count else { return nil }
            let length = (Int(first & 0x1F) << 16) | (Int(bytes[offset + 1]) << 8) | Int(bytes[offset + 2])
            return (length, 3)
        }
        if first & 0xF0 == 0xE0 {
            guard offset + 3 < bytes.count else { return nil }
            let length = (Int(first & 0x0F) << 24) | (Int(bytes[offset + 1]) << 16)
                | (Int(bytes[offset + 2]) << 8) | Int(bytes[offset + 3])
            return (length, 4)
        }
        guard offset + 4 < bytes.count else { return nil }
        let length = (Int(bytes[offset + 1]) << 24) | (Int(bytes[offset + 2]) << 16)
            | (Int(bytes[offset + 3]) << 8) | Int(bytes[offset + 4])
        return (length, 5)
    }

    /// Decodes as many complete sentences as are present in `data`.
    /// Returns the sentences (each an array of words).
    static func decodeSentences(_ data: Data) -> [[String]] {
        let bytes = [UInt8](data)
        var sentences: [[String]] = []
        var current: [String] = []
        var offset = 0

        while offset < bytes.count {
            guard let (length, consumed) = decodeLength(bytes, at: offset) else { break }
            offset += consumed
            if length == 0 {
                sentences.append(current)
                current = []
                continue
            }
            guard offset + length <= bytes.count else { break }
            let word = String(decoding: bytes[offset..<offset + length], as: UTF8.self)
            current.append(word)
            offset += length
        }
        if !current.isEmpty { sentences.append(current) }
        return sentences
    }
}
