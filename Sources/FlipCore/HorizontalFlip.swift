import CoreImage

public enum HorizontalFlip {
    /// Reflect in source coordinates, then fit exactly to the output surface.
    /// Core Image retains bottom-left coordinates; no vertical reflection occurs.
    public static func image(_ image: CIImage, outputSize: CGSize) -> CIImage {
        let extent = image.extent
        let normalized = image.transformed(by: .init(translationX: -extent.minX, y: -extent.minY))
        let mirrored = normalized.transformed(by: .init(a: -1, b: 0, c: 0, d: 1,
                                                       tx: extent.width, ty: 0))
        return mirrored.transformed(by: .init(scaleX: outputSize.width / extent.width,
                                              y: outputSize.height / extent.height))
    }
}
