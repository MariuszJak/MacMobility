import Foundation
import UIKit
import Combine

public extension UIImageView {
    // swiftlint:disable multiline_parameters
    func loadImage(with url: URL?, withSpinner: Bool = true,
                   placeholderImage: UIImage? = nil,
                   completion: ((UIImage) -> UIImageView)? = nil,
                   failure: (() -> Void)? = nil) -> AnyCancellable {
        image = nil
        if url == nil {
            image = placeholderImage
        }

        if withSpinner {
            addSpinner()
        }

        return Switlfy.loadImage(from: url)
            .sink { error in
                switch error {
                case .failure(let error):
                    if withSpinner {
                        self.removeSpinner()
                    }
                    failure?()
                    Log.error(error.localizedDescription)
                case .finished:
                    break
                }
            } receiveValue: { image in
                if withSpinner {
                    self.removeSpinner()
                }
                guard let image = image else {
                    failure?()
                    return
                }
                completion?(image)
                self.image = image
            }
    }
}
