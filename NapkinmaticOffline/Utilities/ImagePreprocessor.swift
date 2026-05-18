import UIKit

enum ImagePreprocessorError: LocalizedError {
    case unableToRender
    case unableToEncode

    var errorDescription: String? {
        switch self {
        case .unableToRender:
            return "Could not prepare the selected image for model input."
        case .unableToEncode:
            return "Could not encode the selected image for model input."
        }
    }
}

enum ImagePreprocessor {
    static func encodedJPEGData(
        from image: UIImage,
        maxDimension: CGFloat,
        compressionQuality: CGFloat = 0.88
    ) throws -> Data {
        let normalized = normalizedImage(image)
        let resized = try resizedImage(normalized, maxDimension: maxDimension)

        guard let data = resized.jpegData(compressionQuality: compressionQuality) else {
            throw ImagePreprocessorError.unableToEncode
        }

        return data
    }

    static func resizedImage(_ image: UIImage, maxDimension: CGFloat) throws -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else {
            return image
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
