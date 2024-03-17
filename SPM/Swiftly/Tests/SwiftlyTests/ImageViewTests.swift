import XCTest
import Combine
@testable import Swiftly

// swiftlint:disable force_unwrapping implicitly_unwrapped_optional overridden_super_call
class ImageViewTests: XCTestCase {
    private var cancellableSet: Set<AnyCancellable>!

    override func setUp() {
        Log.logLevel = .disabled
        cancellableSet = Set()
    }

    override func tearDown() {
        Current.api.clearCache()
        cancellableSet = nil
    }

    func testGetImageForUIImageView() {
        let url = URL(string: "http://test/image.jpg")!
        let expectedImage = UIColor.red.image(CGSize(width: 1_024, height: 1_024))
        let expectedImageView = UIImageView()

        Current.imageProvider.loadImage = { _ in Just(expectedImage)
            .mapError { _ in AppError.unknown }
            .eraseToAnyPublisher() }

        expectedImageView.loadImage(with: url).store(in: &cancellableSet)
        XCTAssertEqual(expectedImageView.image, expectedImage)
    }

    func testImageViewPlaceholderImage() {
        let url = URL(string: "http://test/image.jpg")!
        let expectedImageView = UIImageView()
        let expectedPlaceholderImage = UIColor.yellow.image(CGSize(width: 2_048, height: 2_048))

        Current.imageProvider.loadImage = { _ in Just(nil)
            .mapError { _ in AppError.unknown }
            .eraseToAnyPublisher() }

        expectedImageView.loadImage(with: url, placeholderImage: expectedPlaceholderImage).store(in: &cancellableSet)
        XCTAssertEqual(expectedImageView.image, expectedPlaceholderImage)
    }

    func testImageViewPlaceholderImageWithoutSpinner() {
        let url = URL(string: "http://test/image.jpg")!
        let expectedImageView = UIImageView()
        let expectedPlaceholderImage = UIColor.yellow.image(CGSize(width: 2_048, height: 2_048))

        Current.imageProvider.loadImage = { _ in Just(nil)
            .mapError { _ in AppError.unknown }
            .eraseToAnyPublisher() }

        expectedImageView.loadImage(with: url, placeholderImage: expectedPlaceholderImage).store(in: &cancellableSet)
        XCTAssertFalse(expectedImageView.subviews.contains { $0 is UIActivityIndicatorView })
    }

    func testImageViewFailedRequest() {
        let expectedImageView = UIImageView()

        Log.logLevel = .error

        Current.imageProvider.loadImage = { _ in Fail(error: AppError.urlError)
            .eraseToAnyPublisher() }

        expectedImageView.loadImage(with: nil)
            .store(in: &cancellableSet)

        XCTAssertFalse(expectedImageView.subviews.contains { $0 is UIActivityIndicatorView })
    }
}
