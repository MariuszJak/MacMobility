import Foundation
import UIKit
import Lottie

public extension UIImageView {
    func addSpinner() {
        guard !hasSpinner() else {
            return
        }
        let animationView = LottieAnimationView(name: "loader")
        self.addSubview(animationView)

        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFit
        animationView.animationSpeed = 1.8
        animationView.play(completion: nil)

        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: centerYAnchor),
            animationView.heightAnchor.constraint(equalToConstant: 70),
            animationView.widthAnchor.constraint(equalToConstant: 70)
        ])
    }

    func removeSpinner() {
        for view in subviews {
            if let loader = view as? LottieAnimationView {
                loader.stop()
                loader.removeFromSuperview()
            }
        }
    }

    func hasSpinner() -> Bool {
        subviews.contains(where: { $0 is LottieAnimationView })
    }
}
