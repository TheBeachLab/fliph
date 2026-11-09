import AppKit
import MetalKit
import CoreImage
import FlipCore

final class MirrorPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The only AppKit bridge: a non-activating, click-through GPU presentation.
@MainActor
final class MirrorSurface: NSObject, MTKViewDelegate {
    let panel: MirrorPanel
    private let metalView: MTKView
    private let context: CIContext
    private let commandQueue: MTLCommandQueue
    private let frames: FrameMailbox
    private let screenFrame: CGRect
    private let mirroredCursorFrame: CGRect
    private let displayID: CGDirectDisplayID
    private var cursorHidden = false
    private var menuTrackingDepth = 0
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let cursorImage: CIImage?
    private let cursorHotspot: CGPoint

    init(screen: NSScreen, frames: FrameMailbox) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let id = screen.displayID else { throw FlipError.graphicsUnavailable }
        self.frames = frames
        screenFrame = screen.frame
        let usesSingleScreen = NSScreen.screens.count == 1
        var cursorFrame = screen.frame
        if usesSingleScreen { cursorFrame.size.height -= NSStatusBar.system.thickness }
        mirroredCursorFrame = cursorFrame
        displayID = id
        commandQueue = queue
        context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false])
        metalView = MTKView(frame: NSRect(origin: .zero, size: screen.frame.size), device: device)
        metalView.framebufferOnly = false
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.preferredFramesPerSecond = 30
        metalView.isPaused = true
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 1)

        let cursor = NSCursor.arrow
        cursorHotspot = cursor.hotSpot
        if let data = cursor.image.tiffRepresentation { cursorImage = CIImage(data: data) }
        else { cursorImage = nil }

        panel = MirrorPanel(contentRect: screen.frame,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        // With a single screen, the menu bar must stay above the mirror so the user can stop it.
        panel.level = usesSingleScreen ? .init(rawValue: NSWindow.Level.mainMenu.rawValue - 1) : .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.backgroundColor = .black
        panel.contentView = metalView
        super.init()
        metalView.delegate = self
        if usesSingleScreen {
            NotificationCenter.default.addObserver(self, selector: #selector(menuDidBeginTracking),
                                                   name: NSMenu.didBeginTrackingNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(menuDidEndTracking),
                                                   name: NSMenu.didEndTrackingNotification, object: nil)
        }
    }

    func show() {
        panel.orderFrontRegardless()
        metalView.isPaused = false
    }

    func close() {
        metalView.isPaused = true
        metalView.delegate = nil
        restoreCursor()
        panel.orderOut(nil)
        panel.close()
    }

    func restoreCursor() {
        if cursorHidden {
            CGDisplayShowCursor(displayID)
            cursorHidden = false
        }
    }

    @objc private func menuDidBeginTracking() {
        menuTrackingDepth += 1
        restoreCursor()
    }

    @objc private func menuDidEndTracking() {
        menuTrackingDepth = max(0, menuTrackingDepth - 1)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let buffer = frames.frame(), let drawable = view.currentDrawable,
              let command = commandQueue.makeCommandBuffer() else { return }
        autoreleasepool {
            var source = CIImage(cvPixelBuffer: buffer)
            // Capture excludes the system cursor. Paint it before reflection so the
            // desktop and pointer behave like a hardware H-flip through a mirror.
            let point = NSEvent.mouseLocation
            let showsMirroredCursor = menuTrackingDepth == 0 && mirroredCursorFrame.contains(point)
            if showsMirroredCursor && !cursorHidden {
                if CGDisplayHideCursor(displayID) == .success { cursorHidden = true }
            } else if !showsMirroredCursor { restoreCursor() }

            if showsMirroredCursor, let cursorImage {
                let sx = source.extent.width / screenFrame.width
                let sy = source.extent.height / screenFrame.height
                let cursor = cursorImage.transformed(by: .init(scaleX: sx, y: sy))
                let x = (point.x - screenFrame.minX - cursorHotspot.x) * sx
                let y = (point.y - screenFrame.minY + cursorHotspot.y) * sy - cursor.extent.height
                source = cursor.transformed(by: .init(translationX: x, y: y)).composited(over: source)
                    .cropped(to: source.extent)
            }
            let output = HorizontalFlip.image(source, outputSize: view.drawableSize)
            context.render(output, to: drawable.texture, commandBuffer: command,
                           bounds: CGRect(origin: .zero, size: view.drawableSize), colorSpace: colorSpace)
            command.present(drawable)
            command.commit()
        }
    }
}

enum FlipError: Error {
    case graphicsUnavailable, missingDisplay, captureUnavailable, noFrames
    var message: LocalizedStringResource {
        switch self {
        case .graphicsUnavailable: return "Could not start video output."
        case .missingDisplay: return "Connect an external display and set it to extend your desktop."
        case .captureUnavailable: return "Could not set up screen capture."
        case .noFrames: return "No image was received from the display. Check the screen recording permission."
        }
    }
}
