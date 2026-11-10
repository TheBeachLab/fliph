import CoreGraphics

/// Only display properties that affect capture, placement, or safe access to the menu bar.
public struct MirrorConfiguration: Equatable {
    public struct Screen: Equatable {
        public let id: UInt32
        public let frame: CGRect
        public let pixelSize: CGSize
        public let rotation: Double
        public let canMirror: Bool

        public init(id: UInt32, frame: CGRect, pixelSize: CGSize,
                    rotation: Double = 0, canMirror: Bool = true) {
            self.id = id
            self.frame = frame
            self.pixelSize = pixelSize
            self.rotation = rotation
            self.canMirror = canMirror
        }
    }

    public let screen: Screen
    public let keepsMenuBarVisible: Bool

    public init?(displayID: UInt32, screens: [Screen]) {
        guard let screen = screens.first(where: { $0.id == displayID && $0.canMirror }) else { return nil }
        self.screen = screen
        keepsMenuBarVisible = screens.count == 1
    }
}
