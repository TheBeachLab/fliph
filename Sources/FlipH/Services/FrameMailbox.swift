import ScreenCaptureKit

/// A single replaceable frame keeps capture independent of UI/GPU latency.
final class FrameMailbox: NSObject, SCStreamOutput {
    private let lock = NSLock()
    private var latest: CVPixelBuffer?
    private(set) var receivedFrames = 0

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        lock.lock()
        latest = buffer
        receivedFrames += 1
        lock.unlock()
    }

    func frame() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return latest
    }
}
