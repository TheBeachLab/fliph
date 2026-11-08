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
    private let displayID: CGDirectDisplayID
    private var cursorHidden = false
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let cursorImage: CIImage?
    private let cursorHotspot: CGPoint

    init(screen: NSScreen, frames: FrameMailbox) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let id = screen.displayID else { throw FlipError.graphicsUnavailable }
        self.frames = frames
        screenFrame = screen.frame
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
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.backgroundColor = .black
        panel.contentView = metalView
        super.init()
        metalView.delegate = self
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

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let buffer = frames.frame(), let drawable = view.currentDrawable,
              let command = commandQueue.makeCommandBuffer() else { return }
        autoreleasepool {
            var source = CIImage(cvPixelBuffer: buffer)
            // Capture excludes the system cursor. Paint it before reflection so the
            // desktop and pointer behave like a hardware H-flip through a mirror.
            let point = NSEvent.mouseLocation
            let isOverTarget = screenFrame.contains(point)
            if isOverTarget && !cursorHidden {
                if CGDisplayHideCursor(displayID) == .success { cursorHidden = true }
            } else if !isOverTarget { restoreCursor() }

            if isOverTarget, let cursorImage {
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

enum FlipError: LocalizedError {
    case graphicsUnavailable, missingDisplay, captureUnavailable, escapeUnavailable, noFrames
    var errorDescription: String? {
        switch self {
        case .graphicsUnavailable: return "No se pudo iniciar la salida de vídeo."
        case .missingDisplay: return "Conecta un monitor externo y configúralo como pantalla ampliada."
        case .captureUnavailable: return "No se pudo preparar la captura de pantalla."
        case .escapeUnavailable: return "La tecla Esc está ocupada por otra app. Ciérrala e inténtalo de nuevo."
        case .noFrames: return "El monitor no está enviando imagen. Comprueba el permiso de grabación de pantalla."
        }
    }
}
