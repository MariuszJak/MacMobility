import Foundation
import Combine
import UIKit

enum AppError: Error {
    case urlError
    case unknown

    var localizedDescription: String {
        switch self {
        case .unknown:
            return "unknown"
        case .urlError:
            return "url error"
        }
    }
}

class API: RequestService {
    func loadImage(from url: URL?) -> AnyPublisher<UIImage?, Error> {
        requestImage(url)
    }
}
