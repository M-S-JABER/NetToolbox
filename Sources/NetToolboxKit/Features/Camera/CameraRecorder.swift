import Foundation
import AVFoundation
import CoreMedia

/// Records the live camera stream to an MP4 in the app's Documents directory by
/// writing the already-compressed H.264/H.265 sample buffers straight through
/// `AVAssetWriter` (passthrough — no re-encode). Recording begins on the first
/// keyframe so the file is decodable from the start.
final class CameraRecorder: @unchecked Sendable {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var startedSession = false
    private(set) var isRecording = false
    private(set) var outputURL: URL?

    /// Prepares a new recording file. Returns false if the writer can't be set up.
    func start() -> Bool {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        let name = "NetToolbox-\(Int(Date().timeIntervalSince1970)).mp4"
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil) // passthrough
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else { return false }
        writer.add(input)

        self.writer = writer
        self.input = input
        self.outputURL = url
        self.startedSession = false
        self.isRecording = true
        return true
    }

    /// Appends one compressed frame. Ignored until the first keyframe arrives.
    func append(_ sample: CMSampleBuffer) {
        guard isRecording, let writer, let input else { return }

        if !startedSession {
            guard Self.isKeyframe(sample) else { return }
            let pts = CMSampleBufferGetPresentationTimeStamp(sample)
            guard pts.isValid else { return }
            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: pts)
            }
            startedSession = true
        }
        if input.isReadyForMoreMediaData {
            input.append(sample)
        }
    }

    /// Finalizes the file and returns its URL (nil if writing failed).
    func stop() async -> URL? {
        guard isRecording, let writer, let input else { return nil }
        isRecording = false
        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        let url = writer.status == .completed ? outputURL : nil
        self.writer = nil
        self.input = nil
        self.startedSession = false
        return url
    }

    private static func isKeyframe(_ sample: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[CFString: Any]],
              let first = attachments.first else {
            return true
        }
        if let notSync = first[kCMSampleAttachmentKey_NotSync] as? Bool { return !notSync }
        return true
    }
}
