import XCTest
@testable import FlipCore

final class MirrorConfigurationTests: XCTestCase {
    private let hdmi = MirrorConfiguration.Screen(id: 2, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                                 pixelSize: CGSize(width: 1920, height: 1080))
    private let builtIn = MirrorConfiguration.Screen(id: 1, frame: CGRect(x: -1440, y: 0, width: 1440, height: 900),
                                                    pixelSize: CGSize(width: 2880, height: 1800), canMirror: false)

    func testRepeatedNotificationAndDisplayEnumerationOrderKeepCaptureValid() {
        let captured = MirrorConfiguration(displayID: 2, screens: [builtIn, hdmi])
        XCTAssertNotNil(captured)
        XCTAssertEqual(captured, MirrorConfiguration(displayID: 2, screens: [builtIn, hdmi]))
        XCTAssertEqual(captured, MirrorConfiguration(displayID: 2, screens: [hdmi, builtIn]))
    }

    func testUnrelatedDisplayChangesDoNotInvalidateSelectedDisplay() {
        let captured = MirrorConfiguration(displayID: 2, screens: [builtIn, hdmi])
        let additional = MirrorConfiguration.Screen(id: 3, frame: CGRect(x: 1920, y: 0, width: 1280, height: 720),
                                                   pixelSize: CGSize(width: 1280, height: 720))
        XCTAssertEqual(captured, MirrorConfiguration(displayID: 2, screens: [hdmi, builtIn, additional]))
    }

    func testTargetDisconnectionOrNativeMirroringInvalidatesCapture() {
        XCTAssertNil(MirrorConfiguration(displayID: 2, screens: [builtIn]))
        let nativeMirror = MirrorConfiguration.Screen(id: 2, frame: hdmi.frame, pixelSize: hdmi.pixelSize,
                                                     canMirror: false)
        XCTAssertNil(MirrorConfiguration(displayID: 2, screens: [builtIn, nativeMirror]))
    }

    func testPositionResolutionRotationAndSingleScreenModeRequireReconfiguration() {
        let captured = MirrorConfiguration(displayID: 2, screens: [builtIn, hdmi])
        let changedScreens = [
            MirrorConfiguration.Screen(id: 2, frame: hdmi.frame.offsetBy(dx: 100, dy: 0), pixelSize: hdmi.pixelSize),
            MirrorConfiguration.Screen(id: 2, frame: hdmi.frame, pixelSize: CGSize(width: 3840, height: 2160)),
            MirrorConfiguration.Screen(id: 2, frame: hdmi.frame, pixelSize: hdmi.pixelSize, rotation: 180)
        ]
        for changed in changedScreens {
            XCTAssertNotEqual(captured, MirrorConfiguration(displayID: 2, screens: [builtIn, changed]))
        }
        XCTAssertNotEqual(captured, MirrorConfiguration(displayID: 2, screens: [hdmi]))
        XCTAssertEqual(MirrorConfiguration(displayID: 2, screens: [hdmi])?.keepsMenuBarVisible, true)
    }
}
