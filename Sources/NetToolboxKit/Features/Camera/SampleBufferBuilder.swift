import Foundation
import CoreMedia

/// Bridges raw NAL units into CoreMedia objects the display layer understands:
/// a `CMVideoFormatDescription` compiled from parameter sets, and per-frame
/// `CMSampleBuffer`s in AVCC (length-prefixed) layout. All hardware decoding is
/// then done by `AVSampleBufferDisplayLayer` — no external codec library.
enum SampleBufferBuilder {
    /// Compiles SPS/PPS (H.264) or VPS/SPS/PPS (H.265) into a format description.
    static func makeFormat(parameterSets sets: [Data], codec: VideoCodec) -> CMFormatDescription? {
        guard !sets.isEmpty else { return nil }

        // Stable heap copies so the pointers stay valid across the C call.
        var allocations: [UnsafeMutablePointer<UInt8>] = []
        var pointers: [UnsafePointer<UInt8>] = []
        var sizes: [Int] = []
        for set in sets {
            let count = set.count
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            set.copyBytes(to: buffer, count: count)
            allocations.append(buffer)
            pointers.append(UnsafePointer(buffer))
            sizes.append(count)
        }
        defer { allocations.forEach { $0.deallocate() } }

        var format: CMFormatDescription?
        let status = pointers.withUnsafeBufferPointer { pp -> OSStatus in
            sizes.withUnsafeBufferPointer { sp -> OSStatus in
                switch codec {
                case .h264:
                    return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: sets.count,
                        parameterSetPointers: pp.baseAddress!,
                        parameterSetSizes: sp.baseAddress!,
                        nalUnitHeaderLength: 4,
                        formatDescriptionOut: &format
                    )
                case .h265:
                    return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: sets.count,
                        parameterSetPointers: pp.baseAddress!,
                        parameterSetSizes: sp.baseAddress!,
                        nalUnitHeaderLength: 4,
                        extensions: nil,
                        formatDescriptionOut: &format
                    )
                }
            }
        }
        return status == noErr ? format : nil
    }

    /// Wraps one access unit (its NAL units) as a display-ready sample buffer.
    static func make(accessUnit: [Data], format: CMFormatDescription, pts: CMTime) -> CMSampleBuffer? {
        // Convert Annex-B-style NALs into AVCC: 4-byte big-endian length + bytes.
        var avcc = Data()
        for nal in accessUnit {
            var length = UInt32(nal.count).bigEndian
            withUnsafeBytes(of: &length) { avcc.append(contentsOf: $0) }
            avcc.append(nal)
        }
        let length = avcc.count
        guard length > 4 else { return nil }

        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: length,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: length,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == kCMBlockBufferNoErr, let blockBuffer else { return nil }

        status = avcc.withUnsafeBytes { raw in
            CMBlockBufferReplaceDataBytes(
                with: raw.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: length
            )
        }
        guard status == kCMBlockBufferNoErr else { return nil }

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var sampleSize = length
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else { return nil }

        // Render as soon as decoded — low-latency live view, no queued playback.
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }
        return sampleBuffer
    }
}
