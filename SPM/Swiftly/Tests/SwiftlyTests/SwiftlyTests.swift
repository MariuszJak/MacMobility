import XCTest
import Combine
@testable import Swiftly

// swiftlint:disable force_unwrapping implicitly_unwrapped_optional overridden_super_call
final class SwiftlyTests: XCTestCase {
    private var cancellableSet: Set<AnyCancellable>!

    override func setUp() {
        cancellableSet = Set()
    }

    // swiftlint:disable empty_xctest_method
    override func tearDown() {
        cancellableSet = nil
    }

    func testGetImage() {
        let url = URL(string: "http://test/image.jpg")!
        let expectedImage = UIColor.red.image(CGSize(width: 1_024, height: 1_024))

        Current.imageProvider.loadImage = { _ in Just(expectedImage)
            .mapError { _ in AppError.unknown }
            .eraseToAnyPublisher() }

        Switlfy.loadImage(from: url)
            .sink { error in
                switch error {
                case .failure, .finished:
                    break
                }
            } receiveValue: { image in
                XCTAssertEqual(expectedImage, image)
            }
            .store(in: &cancellableSet)
    }

    func testgetImageWithError() {
        let url = URL(string: "http://test/image.jpg")!

        Current.imageProvider.loadImage = { _ in Fail(error: AppError.urlError)
            .eraseToAnyPublisher() }

        Switlfy.loadImage(from: url)
            .sink { error in
                switch error {
                case .failure(let error):
                    XCTAssertEqual((error as? AppError)?.localizedDescription, AppError.urlError.localizedDescription)
                case .finished:
                    XCTFail()
                }
            } receiveValue: { _ in
            }
            .store(in: &cancellableSet)
    }

    func testgetImageWithUnknowError() {
        let url = URL(string: "http://test/image.jpg")!

        Current.imageProvider.loadImage = { _ in Fail(error: AppError.unknown)
            .eraseToAnyPublisher() }

        Switlfy.loadImage(from: url)
            .sink { error in
                switch error {
                case .failure(let error):
                    XCTAssertEqual((error as? AppError)?.localizedDescription, AppError.unknown.localizedDescription)
                case .finished:
                    XCTFail()
                }
            } receiveValue: { _ in
            }
            .store(in: &cancellableSet)
    }

    func testLogLevel() {
        Switlfy.setLog(with: .debug)
        XCTAssertEqual(Log.logLevel.rawValue, 3)
    }
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
