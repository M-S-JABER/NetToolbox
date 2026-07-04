import Foundation

/// SSH binary encoding primitives (RFC 4251 §5). Pure and unit-tested:
/// the transport layer builds and parses every packet through these.
enum SSHWire {
    /// Appends a `uint32` in network byte order.
    static func putUInt32(_ value: UInt32, into data: inout Data) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// Appends an SSH `string`: a `uint32` length followed by the raw bytes.
    static func putString(_ bytes: Data, into data: inout Data) {
        putUInt32(UInt32(bytes.count), into: &data)
        data.append(bytes)
    }

    /// Appends an SSH `string` from UTF-8 text.
    static func putString(_ text: String, into data: inout Data) {
        putString(Data(text.utf8), into: &data)
    }

    /// Appends a comma-joined `name-list` as an SSH `string`.
    static func putNameList(_ names: [String], into data: inout Data) {
        putString(names.joined(separator: ","), into: &data)
    }

    /// Appends an `mpint` (RFC 4251 §5): a two's-complement big-endian
    /// integer. A leading zero byte is inserted when the high bit is set so
    /// the value is never misread as negative; zero encodes as empty.
    static func putMPInt(_ magnitude: Data, into data: inout Data) {
        var bytes = Array(magnitude)
        while bytes.first == 0 { bytes.removeFirst() }   // strip leading zeros
        if bytes.isEmpty {
            putUInt32(0, into: &data)
            return
        }
        if bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
        putString(Data(bytes), into: &data)
    }

    /// Sequential reader over an SSH payload.
    struct Reader {
        private let data: Data
        private var index: Int

        init(_ data: Data) {
            self.data = data
            self.index = data.startIndex
        }

        var isAtEnd: Bool { index >= data.endIndex }
        var remaining: Data { data[index...] }

        mutating func readByte() -> UInt8? {
            guard index < data.endIndex else { return nil }
            defer { index += 1 }
            return data[index]
        }

        mutating func readUInt32() -> UInt32? {
            guard index + 4 <= data.endIndex else { return nil }
            let slice = data[index..<index + 4]
            index += 4
            return slice.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }

        mutating func readUInt64() -> UInt64? {
            guard index + 8 <= data.endIndex else { return nil }
            let slice = data[index..<index + 8]
            index += 8
            return slice.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }

        mutating func readString() -> Data? {
            guard let length = readUInt32() else { return nil }
            let count = Int(length)
            guard index + count <= data.endIndex else { return nil }
            let slice = data[index..<index + count]
            index += count
            return Data(slice)
        }

        mutating func readStringUTF8() -> String? {
            guard let bytes = readString() else { return nil }
            return String(decoding: bytes, as: UTF8.self)
        }

        mutating func readNameList() -> [String]? {
            guard let text = readStringUTF8() else { return nil }
            return text.isEmpty ? [] : text.components(separatedBy: ",")
        }
    }
}
