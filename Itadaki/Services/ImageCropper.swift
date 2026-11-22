import UIKit

/// Image preparation and cropping. All inputs/outputs here are upright (`.up`)
/// images at scale 1, so pixel size == `size`.
enum ImageCropper {
    /// Long edge sent to the API.
    static let uploadLongEdge: CGFloat = 1568
    /// Long edge kept on device for cropping dish photos and showing the page.
    static let workingLongEdge: CGFloat = 3000

    /// Redraws `image` upright, downscaled so its long edge is at most `maxLongEdge`.
    static func normalized(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        let ratio = longEdge > maxLongEdge ? maxLongEdge / longEdge : 1
        let target = CGSize(
            width: max(1, (size.width * ratio).rounded()), height: max(1, (size.height * ratio).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// JPEG for upload: long edge ≈ 1568 px, quality 0.8.
    static func uploadJPEG(from image: UIImage) -> Data? {
        normalized(image, maxLongEdge: uploadLongEdge).jpegData(compressionQuality: 0.8)
    }

    /// Crops the region described by a normalized box. Boxes are relative to the
    /// uploaded image, which has the same aspect ratio as `image`.
    static func crop(
        _ image: UIImage, to bbox: NormalizedRect, padding: Double = CropMath.defaultPadding
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        guard let rect = CropMath.cropRect(for: bbox, imageSize: pixelSize, padding: padding),
            let cropped = cgImage.cropping(to: rect)
        else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}
