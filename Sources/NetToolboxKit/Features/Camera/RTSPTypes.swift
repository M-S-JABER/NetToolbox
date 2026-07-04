import Foundation

/// Video codec carried by an RTSP stream. Only the two codecs iOS can decode
/// in hardware via VideoToolbox are modelled.
enum VideoCodec: Sendable, Equatable {
    case h264
    case h265
}

/// The subset of an SDP `DESCRIBE` body we need to start decoding: which video
/// track to `SETUP`, its codec, RTP payload type and the out-of-band parameter
/// sets (SPS/PPS, plus VPS for H.265) advertised in the `fmtp` line.
struct SDPVideoMedia: Sendable, Equatable {
    var codec: VideoCodec
    var payloadType: Int
    /// Track control URL (absolute, or relative to the content base).
    var control: String
    /// Raw parameter-set NAL units (no start codes), decoded from base64.
    var parameterSets: [Data]
    /// RTP clock rate (Hz); 90000 for video in practice.
    var clockRate: Int
}

/// Minimal SDP reader focused on the first decodable video media section.
enum SDPParser {
    static func parseVideo(_ sdp: String) -> SDPVideoMedia? {
        // Split into global lines and per-media sections. A media section starts
        // at an `m=` line and runs until the next `m=`.
        let lines = sdp
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var inVideo = false
        var payloadType = -1
        var codec: VideoCodec?
        var control = ""
        var clockRate = 90000
        var parameterSets: [Data] = []

        for line in lines {
            if line.hasPrefix("m=") {
                // Entering a new media section — commit only video, reset state.
                if line.hasPrefix("m=video") {
                    inVideo = true
                    // First payload type on the m= line, e.g. "m=video 0 RTP/AVP 96".
                    let parts = line.split(separator: " ")
                    if parts.count >= 4, let pt = Int(parts[3]) { payloadType = pt }
                } else {
                    // A non-video section after we already captured video ends parsing.
                    if inVideo, codec != nil { break }
                    inVideo = false
                }
                continue
            }
            guard inVideo else { continue }

            if line.hasPrefix("a=rtpmap:") {
                // a=rtpmap:96 H264/90000
                let value = line.dropFirst("a=rtpmap:".count)
                let fields = value.split(separator: " ")
                guard fields.count >= 2 else { continue }
                let encoding = fields[1].uppercased()
                if encoding.hasPrefix("H264") { codec = .h264 }
                else if encoding.hasPrefix("H265") || encoding.hasPrefix("HEVC") { codec = .h265 }
                let rateParts = fields[1].split(separator: "/")
                if rateParts.count >= 2, let rate = Int(rateParts[1]) { clockRate = rate }
            } else if line.hasPrefix("a=control:") {
                control = String(line.dropFirst("a=control:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("a=fmtp:") {
                parameterSets = parseParameterSets(line, codec: codec)
            }
        }

        guard let codec else { return nil }
        if payloadType < 0 { payloadType = 96 }
        return SDPVideoMedia(
            codec: codec,
            payloadType: payloadType,
            control: control,
            parameterSets: parameterSets,
            clockRate: clockRate
        )
    }

    /// Pulls SPS/PPS (H.264) or VPS/SPS/PPS (H.265) out of an `a=fmtp` line.
    private static func parseParameterSets(_ line: String, codec: VideoCodec?) -> [Data] {
        // Everything after the first space is a `;`-separated parameter list.
        guard let spaceIndex = line.firstIndex(of: " ") else { return [] }
        let params = line[line.index(after: spaceIndex)...]
        var sets: [Data] = []

        func decodeList(_ csv: Substring) {
            for token in csv.split(separator: ",") {
                let trimmed = token.trimmingCharacters(in: .whitespaces)
                if let data = Data(base64Encoded: trimmed), !data.isEmpty {
                    sets.append(data)
                }
            }
        }

        for pair in params.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let keyName = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = kv[1]
            switch keyName {
            case "sprop-parameter-sets":
                // H.264: "SPS,PPS" base64.
                decodeList(value)
            case "sprop-vps", "sprop-sps", "sprop-pps":
                // H.265: three separate base64 attributes.
                decodeList(value)
            default:
                continue
            }
        }
        return sets
    }
}
