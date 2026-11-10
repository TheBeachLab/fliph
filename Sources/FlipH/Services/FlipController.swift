import AppKit
import Combine
import ScreenCaptureKit
import FlipCore
import OSLog

@MainActor
final class FlipController: NSObject, ObservableObject, SCStreamDelegate {
    static let shared = FlipController()
    @Published var displays: [ExternalDisplay] = []
    @Published var selectedID: CGDirectDisplayID = 0
    @Published private(set) var active = false
    @Published private(set) var busy = false
    @Published private(set) var message: LocalizedStringResource?
    @Published var needsPermission = false
    private var stream: SCStream?
    private var surface: MirrorSurface?
    private var captureConfiguration: MirrorConfiguration?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "local.fran.fliph", category: "Capture")
    private var generation = 0
    private var observers: [NSObjectProtocol] = []
    private weak var controls: NSWindow?
    private let captureQueue = DispatchQueue(label: "local.fran.fliph.capture", qos: .userInteractive)

    override init() {
        super.init()
        refreshDisplays()
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // macOS also sends this notification without changing display geometry.
                // In particular, screen-sharing UI must not stop a newly started mirror.
                if (self.active || self.busy),
                   self.captureConfiguration != self.currentCaptureConfiguration() {
                    self.logger.notice("Stopping mirroring because the capture display configuration changed")
                    self.stop()
                    self.message = "The display arrangement changed. You can turn mirroring on again."
                } else if self.active || self.busy {
                    self.logger.info("Ignoring screen notification: capture display configuration is unchanged")
                }
                self.refreshDisplays()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.stop() } })
    }

    func refreshDisplays() {
        displays = ExternalDisplay.connected()
        if !displays.contains(where: { $0.id == selectedID }) { selectedID = displays.first?.id ?? 0 }
    }

    private func currentCaptureConfiguration() -> MirrorConfiguration? {
        let screens = NSScreen.screens.compactMap { screen -> MirrorConfiguration.Screen? in
            guard let id = screen.displayID else { return nil }
            return .init(id: id, frame: screen.frame,
                         pixelSize: CGSize(width: CGDisplayPixelsWide(id), height: CGDisplayPixelsHigh(id)),
                         rotation: CGDisplayRotation(id),
                         canMirror: CGDisplayIsActive(id) != 0 && CGDisplayIsBuiltin(id) == 0 && CGDisplayIsInMirrorSet(id) == 0)
        }
        return MirrorConfiguration(displayID: selectedID, screens: screens)
    }

    func start() async {
        guard !active, !busy else { return }
        busy = true
        message = nil
        needsPermission = false
        generation += 1
        let operation = generation
        defer { if generation == operation { busy = false } }
        guard let screen = NSScreen.screens.first(where: { $0.displayID == selectedID }),
              let configuration = currentCaptureConfiguration() else {
            message = FlipError.missingDisplay.message
            return
        }
        captureConfiguration = configuration
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            logger.error("Screen capture permission was denied for this app identity")
            needsPermission = true
            message = "Allow Flip H to capture your screen in System Settings, then reopen the app."
            return
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard generation == operation else { return }
            guard let display = content.displays.first(where: { $0.displayID == selectedID }),
                  let ownApp = content.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier })
            else { throw FlipError.captureUnavailable }
            // Excluding all of this app's windows prevents a recursive mirror feedback loop.
            let filter = SCContentFilter(display: display, excludingApplications: [ownApp], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = CGDisplayPixelsWide(selectedID)
            configuration.height = CGDisplayPixelsHigh(selectedID)
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 3
            configuration.showsCursor = false
            configuration.capturesAudio = false
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.colorSpaceName = CGColorSpace.sRGB
            let frames = FrameMailbox()
            let surface = try MirrorSurface(screen: screen, frames: frames)
            let capture = SCStream(filter: filter, configuration: configuration, delegate: self)
            try capture.addStreamOutput(frames, type: .screen, sampleHandlerQueue: captureQueue)
            self.surface = surface
            self.stream = capture
            try await capture.startCapture()
            // Wait for a real frame before covering the physical screen.
            for _ in 0..<100 {
                guard generation == operation else { try? await capture.stopCapture(); return }
                if frames.frame() != nil { break }
                try await Task.sleep(nanoseconds: 30_000_000)
            }
            guard frames.frame() != nil else { throw FlipError.noFrames }
            guard generation == operation else { return }
            active = true
            logger.notice("Mirroring started after receiving a complete frame")
            controls = NSApp.windows.first(where: { $0.styleMask.contains(.titled) && $0.isVisible })
            // Keep the controls off the mirrored screen. With one screen, use the menu bar to stop.
            if let other = NSScreen.screens.first(where: { $0.displayID != selectedID }), let controls {
                controls.setFrameOrigin(NSPoint(x: other.visibleFrame.midX - controls.frame.width / 2,
                                                y: other.visibleFrame.midY - controls.frame.height / 2))
            } else { controls?.orderOut(nil) }
            surface.show()
        } catch {
            guard generation == operation else { return }
            logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
            stop()
            message = (error as? FlipError)?.message ?? "\(error.localizedDescription)"
        }
    }

    func stop(showControls: Bool = true) {
        generation += 1
        surface?.close()
        surface = nil
        captureConfiguration = nil
        let oldStream = stream
        stream = nil
        active = false
        busy = false
        if let oldStream { Task { try? await oldStream.stopCapture() } }
        if showControls { controls?.makeKeyAndOrderFront(nil) }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.stream === stream else { return }
            self.stop()
            self.message = "\(error.localizedDescription)"
        }
    }

    func openPermissions() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}
