import AppKit

struct ExternalDisplay: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let size: CGSize

    static func connected() -> [ExternalDisplay] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.displayID, CGDisplayIsBuiltin(id) == 0,
                  CGDisplayIsActive(id) != 0, CGDisplayIsInMirrorSet(id) == 0 else { return nil }
            return ExternalDisplay(id: id, name: screen.localizedName, size: screen.frame.size)
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
