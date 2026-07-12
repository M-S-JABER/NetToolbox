import SwiftUI
import Observation
import UniformTypeIdentifiers

/// One entry in a remote SFTP directory listing.
struct SFTPEntry: Identifiable, Equatable, Sendable {
    let name: String
    let longname: String
    let size: UInt64
    let isDirectory: Bool

    var id: String { name }
}

/// Pure builders/parsers for the SFTP v3 subsystem protocol (RFC draft
/// draft-ietf-secsh-filexfer-02). Each packet is `uint32 length | byte type
/// | payload`; the transport (`SSHClient`) carries them inside channel data.
enum SFTPProtocol {
    static let status: UInt8 = 101
    static let handle: UInt8 = 102
    static let data: UInt8 = 103
    static let name: UInt8 = 104

    private static func packet(type: UInt8, body: Data) -> Data {
        var out = Data()
        SSHWire.putUInt32(UInt32(1 + body.count), into: &out)
        out.append(type)
        out.append(body)
        return out
    }

    private static func putUInt64(_ value: UInt64, into data: inout Data) {
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((value >> UInt64(shift)) & 0xFF))
        }
    }

    static func initPacket(version: UInt32) -> Data {
        var body = Data()
        SSHWire.putUInt32(version, into: &body)
        return packet(type: 1, body: body)          // SSH_FXP_INIT
    }

    static func openDir(id: UInt32, path: String) -> Data {
        var body = Data()
        SSHWire.putUInt32(id, into: &body)
        SSHWire.putString(path, into: &body)
        return packet(type: 11, body: body)         // SSH_FXP_OPENDIR
    }

    static func readDir(id: UInt32, handle: Data) -> Data {
        var body = Data()
        SSHWire.putUInt32(id, into: &body)
        SSHWire.putString(handle, into: &body)
        return packet(type: 12, body: body)         // SSH_FXP_READDIR
    }

    static func close(id: UInt32, handle: Data) -> Data {
        var body = Data()
        SSHWire.putUInt32(id, into: &body)
        SSHWire.putString(handle, into: &body)
        return packet(type: 4, body: body)          // SSH_FXP_CLOSE
    }

    static func openFile(id: UInt32, path: String) -> Data {
        var body = Data()
        SSHWire.putUInt32(id, into: &body)
        SSHWire.putString(path, into: &body)
        SSHWire.putUInt32(0x0000_0001, into: &body)  // pflags: READ
        SSHWire.putUInt32(0, into: &body)            // ATTRS flags: none
        return packet(type: 3, body: body)          // SSH_FXP_OPEN
    }

    static func readFile(id: UInt32, handle: Data, offset: UInt64, length: UInt32) -> Data {
        var body = Data()
        SSHWire.putUInt32(id, into: &body)
        SSHWire.putString(handle, into: &body)
        putUInt64(offset, into: &body)
        SSHWire.putUInt32(length, into: &body)
        return packet(type: 5, body: body)          // SSH_FXP_READ
    }

    /// Parses a HANDLE reply's opaque handle.
    static func parseHandle(_ payload: Data) -> Data? {
        var reader = SSHWire.Reader(payload)
        guard reader.readByte() == handle, reader.readUInt32() != nil else { return nil }
        return reader.readString()
    }

    /// Parses a DATA reply's bytes.
    static func parseData(_ payload: Data) -> Data? {
        var reader = SSHWire.Reader(payload)
        guard reader.readByte() == data, reader.readUInt32() != nil else { return nil }
        return reader.readString()
    }

    /// Parses a NAME reply into entries (filename, longname, attrs).
    static func parseName(_ payload: Data) -> [SFTPEntry] {
        var reader = SSHWire.Reader(payload)
        guard reader.readByte() == name, reader.readUInt32() != nil,
              let count = reader.readUInt32() else { return [] }

        var entries: [SFTPEntry] = []
        for _ in 0..<count {
            guard let filename = reader.readStringUTF8(),
                  let longname = reader.readStringUTF8() else { break }
            let attrs = parseAttrs(&reader)
            let isDir: Bool
            if let permissions = attrs.permissions {
                isDir = (permissions & 0o170000) == 0o040000   // S_IFDIR
            } else {
                isDir = longname.hasPrefix("d")                // ls -l style fallback
            }
            entries.append(SFTPEntry(name: filename, longname: longname, size: attrs.size ?? 0, isDirectory: isDir))
        }
        return entries
    }

    private static func parseAttrs(_ reader: inout SSHWire.Reader) -> (size: UInt64?, permissions: UInt32?) {
        guard let flags = reader.readUInt32() else { return (nil, nil) }
        var size: UInt64?
        var permissions: UInt32?
        if flags & 0x0000_0001 != 0 { size = reader.readUInt64() }
        if flags & 0x0000_0002 != 0 { _ = reader.readUInt32(); _ = reader.readUInt32() }   // uid, gid
        if flags & 0x0000_0004 != 0 { permissions = reader.readUInt32() }
        if flags & 0x0000_0008 != 0 { _ = reader.readUInt32(); _ = reader.readUInt32() }   // atime, mtime
        if flags & 0x8000_0000 != 0, let extCount = reader.readUInt32() {
            // `extCount` is attacker-controlled: bound it and stop the moment
            // the wire runs out so a bogus count can't spin.
            for _ in 0..<min(extCount, 256) {
                guard reader.readString() != nil, reader.readString() != nil else { break }
            }
        }
        return (size, permissions)
    }
}
