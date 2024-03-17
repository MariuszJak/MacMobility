import XCTest
import Combine
@testable import Swiftly

// swiftlint:disable force_unwrapping
class ImageCacheTypeTests: XCTestCase {
    func testDecodedImage() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache.insertImage(expectedImage, for: url)

        let decodedImageFromCache = cache.decodedImageCache.object(forKey: url as AnyObject) as? UIImage
        XCTAssertEqual(expectedImage, decodedImageFromCache)
    }

    func testEncodedImage() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache.insertImage(expectedImage, for: url)

        let decodedImage = cache.imageCache.object(forKey: url as AnyObject) as? UIImage
        XCTAssertEqual(expectedImage.decodedImage().size, decodedImage?.size)
    }

    func testRemoveImage() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache.insertImage(expectedImage, for: url)
        cache.removeImage(for: url)
        let image = cache.imageCache.object(forKey: url as AnyObject) as? UIImage
        XCTAssertNil(image)
    }

    func testRemoveAllImages() {
        let firstExpectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                          height: 1_024))
        let secondExpectedImage = UIColor.yellow.image(CGSize(width: 1_024,
                                                              height: 1_024))
        let firstUrl = URL(string: "http://test/image.jpg")!
        let secondUrl = URL(string: "http://test/image2.jpg")!

        let cache = ImageCache(config: .defaultConfig)

        cache.insertImage(firstExpectedImage, for: firstUrl)
        cache.insertImage(secondExpectedImage, for: secondUrl)

        cache.removeAllImages()

        let firstImage = cache.imageCache.object(forKey: firstUrl as AnyObject) as? UIImage
        let secondImage = cache.imageCache.object(forKey: secondUrl as AnyObject) as? UIImage
        XCTAssertNil(firstImage)
        XCTAssertNil(secondImage)
    }

    func testFirstLevelCacheImage() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache.insertImage(expectedImage, for: url)
        let cachedImage = cache.image(for: url)
        XCTAssertEqual(expectedImage, cachedImage)
    }

    func testSecondLevelCacheImage() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache.insertImage(expectedImage, for: url)
        cache.decodedImageCache.removeAllObjects()
        let cachedImage = cache.image(for: url)
        XCTAssertEqual(expectedImage.diskSize, cachedImage?.diskSize)
    }

    func testEmptyCache() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache.insertImage(expectedImage, for: url)
        cache.decodedImageCache.removeAllObjects()
        cache.imageCache.removeAllObjects()
        let cachedImage = cache.image(for: url)
        XCTAssertNil(cachedImage)
    }

    func testSubscript() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!
        let cache = ImageCache(config: .defaultConfig)
        cache[url] = expectedImage
        let cachedImage = cache[url]
        XCTAssertEqual(expectedImage, cachedImage)
    }
}
