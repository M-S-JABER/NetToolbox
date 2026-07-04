import Foundation
import CoreMedia

/// Reassembles RTP video payloads into decodable access units and wraps them as
/// `CMSampleBuffer`s for an `AVSampleBufferDisplayLayer`.
///
/// Implements the two RTP payload formats iOS can decode in hardware:
/// * **H.264** — RFC 6184 (single NAL, STAP-A aggregation, FU-A fragmentation)
/// * **H.265** — RFC 7798 (single NAL, AP aggregation, FU fragmentation)
///
/// Parameter sets (SPS/PPS, plus VPS for H.265) are taken from the SDP if the
/// camera advertises them and refreshed from any that appear inline in the
/// stream, then compiled into a `CMVideoFormatDescription` via CoreMedia.
final class VideoDepacketizer {
    private let codec: VideoCodec
    private let clockRate: Int32
    private let onSample: (CMSampleBuffer) -> Void

    private var sps: Data?
    private var pps: Data?
    private var vps: Data?
    private var format: CMFormatDescription?

    private var pendingNALs: [Data] = []
    private var currentTimestamp: UInt32?
    private var fuBuffer: Data?

    init(codec: VideoCodec, clockRate: Int, onSample: @escaping (CMSampleBuffer) -> Void) {
        self.codec = codec
        self.clockRate = Int32(clockRate == 0 ? 90000 : clockRate)
        self.onSample = onSample
    }

    /// Seeds parameter sets discovered out-of-band in the SDP `fmtp` line.
    func seedParameterSets(_ sets: [Data]) {
        for set in sets { classifyParameterSet(set) }
        rebuildFormatIfPossible()
    }

    // MARK: - RTP payload intake

    /// Handles one RTP packet's payload (RTP header already stripped).
    func handle(payload: Data, marker: Bool, timestamp: UInt32) {
        guard !payload.isEmpty else { return }

        // A new timestamp begins a new access unit — flush what we have.
        if let current = currentTimestamp, current != timestamp {
            flush()
        }
        currentTimestamp = timestamp

        switch codec {
        case .h264: handleH264(payload)
        case .h265: handleH265(payload)
        }

        if marker { flush() }
    }

    // MARK: - H.264 (RFC 6184)

    private func handleH264(_ payload: Data) {
        let bytes = [UInt8](payload)
        let type = bytes[0] & 0x1F

        switch type {
        case 1...23:
            addNAL(payload)
        case 24: // STAP-A: [NALU size][NALU]...
            var offset = 1
            while offset + 2 <= bytes.count {
                let size = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
                offset += 2
                guard size > 0, offset + size <= bytes.count else { break }
                addNAL(Data(bytes[offset..<offset + size]))
                offset += size
            }
        case 28: // FU-A fragmentation
            guard bytes.count >= 3 else { return }
            let fuHeader = bytes[1]
            let start = (fuHeader & 0x80) != 0
            let end = (fuHeader & 0x40) != 0
            let nalType = fuHeader & 0x1F
            if start {
                let reconstructedHeader = (bytes[0] & 0xE0) | nalType
                var nal = Data([reconstructedHeader])
                nal.append(contentsOf: bytes[2...])
                fuBuffer = nal
            } else if fuBuffer != nil {
                fuBuffer?.append(contentsOf: bytes[2...])
            }
            if end, let complete = fuBuffer {
                addNAL(complete)
                fuBuffer = nil
            }
        default:
            break // STAP-B / MTAP / FU-B are not used by cameras.
        }
    }

    // MARK: - H.265 (RFC 7798)

    private func handleH265(_ payload: Data) {
        let bytes = [UInt8](payload)
        guard bytes.count >= 2 else { return }
        let type = (bytes[0] >> 1) & 0x3F

        switch type {
        case 0...47:
            addNAL(payload)
        case 48: // AP aggregation: [NALU size][NALU]...
            var offset = 2
            while offset + 2 <= bytes.count {
                let size = Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
                offset += 2
                guard size > 0, offset + size <= bytes.count else { break }
                addNAL(Data(bytes[offset..<offset + size]))
                offset += size
            }
        case 49: // FU fragmentation
            guard bytes.count >= 3 else { return }
            let fuHeader = bytes[2]
            let start = (fuHeader & 0x80) != 0
            let end = (fuHeader & 0x40) != 0
            let fuType = fuHeader & 0x3F
            if start {
                let newByte0 = (bytes[0] & 0x81) | (fuType << 1)
                var nal = Data([newByte0, bytes[1]])
                nal.append(contentsOf: bytes[3...])
                fuBuffer = nal
            } else if fuBuffer != nil {
                fuBuffer?.append(contentsOf: bytes[3...])
            }
            if end, let complete = fuBuffer {
                addNAL(complete)
                fuBuffer = nil
            }
        default:
            break
        }
    }

    // MARK: - Access-unit assembly

    private func addNAL(_ nal: Data) {
        guard let first = nal.first else { return }
        // Capture parameter sets both for the format description and the AU.
        classifyParameterSet(nal)
        if isParameterSet(first) { rebuildFormatIfPossible() }
        pendingNALs.append(nal)
    }

    private func flush() {
        defer { pendingNALs.removeAll(keepingCapacity: true) }
        guard let format, pendingNALs.contains(where: { isVCL($0.first ?? 0) }) else { return }
        let pts = CMTime(value: Int64(currentTimestamp ?? 0), timescale: clockRate)
        if let sample = SampleBufferBuilder.make(accessUnit: pendingNALs, format: format, pts: pts) {
            onSample(sample)
        }
    }

    // MARK: - NAL classification

    private func isVCL(_ header: UInt8) -> Bool {
        switch codec {
        case .h264: return (1...5).contains(header & 0x1F)
        case .h265: return ((header >> 1) & 0x3F) <= 31
        }
    }

    private func isParameterSet(_ header: UInt8) -> Bool {
        switch codec {
        case .h264: let t = header & 0x1F; return t == 7 || t == 8
        case .h265: let t = (header >> 1) & 0x3F; return t == 32 || t == 33 || t == 34
        }
    }

    private func classifyParameterSet(_ nal: Data) {
        guard let header = nal.first else { return }
        switch codec {
        case .h264:
            switch header & 0x1F {
            case 7: sps = nal
            case 8: pps = nal
            default: break
            }
        case .h265:
            switch (header >> 1) & 0x3F {
            case 32: vps = nal
            case 33: sps = nal
            case 34: pps = nal
            default: break
            }
        }
    }

    private func rebuildFormatIfPossible() {
        guard let sps, let pps else { return }
        let sets: [Data]
        switch codec {
        case .h264: sets = [sps, pps]
        case .h265: sets = [vps, sps, pps].compactMap { $0 }
        }
        if let newFormat = SampleBufferBuilder.makeFormat(parameterSets: sets, codec: codec) {
            format = newFormat
        }
    }
}
