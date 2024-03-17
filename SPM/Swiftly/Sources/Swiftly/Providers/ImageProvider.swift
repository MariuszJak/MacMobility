import Foundation
import Combine
import UIKit

class ImageProvider {
    var loadImage: (_ url: URL?) -> AnyPublisher<UIImage?, Error> = { url in
        Current.api.loadImage(from: url)
    }
}
