import Foundation
import UIKit

extension ImageCache: ImageCacheType {
    func insertImage(_ image: UIImage?, for url: URL) {
        guard let image = image else { return removeImage(for: url) }
        let decodedImage = image.decodedImage()

        lock.lock(); defer { lock.unlock() }
        imageCache.setObject(decodedImage, forKey: url as AnyObject)
        decodedImageCache.setObject(image as AnyObject,
                                    forKey: url as AnyObject,
                                    cost: decodedImage.diskSize)
    }

    func removeImage(for url: URL) {
        lock.lock(); defer { lock.unlock() }
        imageCache.removeObject(forKey: url as AnyObject)
        decodedImageCache.removeObject(forKey: url as AnyObject)
    }
}

extension ImageCache {
    func removeAllImages() {
        lock.lock(); defer { lock.unlock() }
        imageCache.removeAllObjects()
        decodedImageCache.removeAllObjects()
    }
}

extension ImageCache {
    func image(for url: URL) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        if let decodedImage = decodedImageCache.object(forKey: url as AnyObject) as? UIImage {
            return decodedImage
        }
        if let image = imageCache.object(forKey: url as AnyObject) as? UIImage {
            let decodedImage = image.decodedImage()
            decodedImageCache.setObject(image as AnyObject,
                                        forKey: url as AnyObject,
                                        cost: decodedImage.diskSize)
            return decodedImage
        }
        return nil
    }
}

extension ImageCache {
    subscript(_ key: URL) -> UIImage? {
        get {
            image(for: key)
        }
        set {
            insertImage(newValue, for: key)
        }
    }
}
