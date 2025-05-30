import Foundation
import FirebaseStorage
import UIKit

class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        // Resize image if needed before compressing
        let maxDimension: CGFloat = 1024 // Define a max dimension for the image
        var scaledImage = image
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let aspectRatio = image.size.width / image.size.height
            let newSize: CGSize
            if aspectRatio > 1 { // Landscape or square
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else { // Portrait
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
            scaledImage = scaledImage.aspectScaled(toFill: newSize)
        }
        
        guard let imageData = scaledImage.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    func deleteImage(at path: String) async throws {
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
    }
}

// Add a helper extension for UIImage resizing
extension UIImage {
    func aspectScaled(toFill size: CGSize) -> UIImage {
        let aspectFillMode = UIView.ContentMode.scaleAspectFill

        let targetSize = size
        let scaledImage = self

        let scalingFactor = min(targetSize.width / scaledImage.size.width,
                                targetSize.height / scaledImage.size.height)
        
        let newSize = CGSize(
            width: scaledImage.size.width * scalingFactor,
            height: scaledImage.size.height * scalingFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        
        let renderedImage = renderer.image { _ in
            scaledImage.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return renderedImage
    }
} 