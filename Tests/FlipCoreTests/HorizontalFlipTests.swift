import XCTest
import CoreImage
@testable import FlipCore

final class HorizontalFlipTests: XCTestCase {
    func testAsymmetricPixelsReverseColumnsAndPreserveRows() {
        // RGBA rows with four distinct opaque pixels expose H/V or 180° mistakes.
        let bytes: [UInt8] = [255,0,0,255, 0,255,0,255, 0,0,255,255, 255,255,0,255]
        let color = CGColorSpace(name: CGColorSpace.sRGB)!
        let source = CIImage(bitmapData: Data(bytes), bytesPerRow: 8,
                             size: CGSize(width: 2, height: 2), format: .RGBA8, colorSpace: color)
        let output = HorizontalFlip.image(source, outputSize: source.extent.size)
        var actual = [UInt8](repeating: 0, count: 16)
        CIContext(options: [.useSoftwareRenderer: true]).render(output, toBitmap: &actual, rowBytes: 8,
            bounds: output.extent, format: .RGBA8, colorSpace: color)
        XCTAssertEqual(actual, [0,255,0,255, 255,0,0,255, 255,255,0,255, 0,0,255,255])
    }

    func testNonzeroOriginAndRetinaScaleProduceExactOutputBounds() {
        let image = CIImage(color: .red).cropped(to: CGRect(x: 100, y: -80, width: 320, height: 180))
        let output = HorizontalFlip.image(image, outputSize: CGSize(width: 640, height: 360))
        XCTAssertEqual(output.extent, CGRect(x: 0, y: 0, width: 640, height: 360))
    }
}
