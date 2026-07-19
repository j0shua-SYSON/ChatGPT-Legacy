import UIKit

enum ImageAttachmentError: LocalizedError {
    case couldNotEncode

    var errorDescription: String? {
        "The selected image could not be prepared for upload."
    }
}

enum ImageAttachmentProcessor {
    static func process(_ image: UIImage) throws -> ChatAttachment {
        let maxDimension: CGFloat = 1_600
        let sourceSize = image.size
        let longest = max(sourceSize.width, sourceSize.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = normalized.jpegData(compressionQuality: 0.78) else {
            throw ImageAttachmentError.couldNotEncode
        }

        return ChatAttachment(
            data: data,
            pixelWidth: Int(targetSize.width),
            pixelHeight: Int(targetSize.height)
        )
    }
}
