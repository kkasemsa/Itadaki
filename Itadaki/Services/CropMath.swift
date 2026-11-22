import Foundation

/// Pure geometry for turning normalized bounding boxes into pixel crop rects.
enum CropMath {
    /// Claude's boxes can be tight or slightly off, so grow them a little by default.
    static let defaultPadding = 0.04
    /// Crops smaller than this on either side are not worth showing.
    static let minimumSide = 16.0

    /// - Parameters:
    ///   - bbox: normalized box, origin top-left.
    ///   - imageSize: pixel size of the image being cropped.
    ///   - padding: fraction of the box's own width/height added on every side.
    /// - Returns: an integral pixel rect inside the image, or nil when too small.
    static func cropRect(
        for bbox: NormalizedRect,
        imageSize: CGSize,
        padding: Double = defaultPadding
    ) -> CGRect? {
        let imageWidth = Double(imageSize.width)
        let imageHeight = Double(imageSize.height)
        guard imageWidth >= 1, imageHeight >= 1 else { return nil }

        let padX = bbox.width * padding
        let padY = bbox.height * padding
        let minX = max(0, ((bbox.x - padX) * imageWidth).rounded(.down))
        let minY = max(0, ((bbox.y - padY) * imageHeight).rounded(.down))
        let maxX = min(imageWidth, ((bbox.x + bbox.width + padX) * imageWidth).rounded(.up))
        let maxY = min(imageHeight, ((bbox.y + bbox.height + padY) * imageHeight).rounded(.up))

        let width = maxX - minX
        let height = maxY - minY
        guard width >= minimumSide, height >= minimumSide else { return nil }
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
}
