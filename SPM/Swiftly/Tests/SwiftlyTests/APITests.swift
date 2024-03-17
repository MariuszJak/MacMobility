import XCTest
import Combine
@testable import Swiftly

// swiftlint:disable force_unwrapping implicitly_unwrapped_optional overridden_super_call
class APITests: XCTestCase {
    private var cancellableSet: Set<AnyCancellable>!

    override func setUp() {
        cancellableSet = Set()
    }

    // swiftlint:disable empty_xctest_method
    override func tearDown() {
        cancellableSet = nil
    }

    func testImageRequest() {
        let expectedImage = UIColor.red.image(CGSize(width: 1_024,
                                                     height: 1_024))
        let url = URL(string: "http://test/image.jpg")!

        Current.cache.insertImage(expectedImage, for: url)

        Current.api.loadImage(from: url)
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

    func testImageRequestWithBadURL() {
        Current.api.loadImage(from: nil)
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
}
