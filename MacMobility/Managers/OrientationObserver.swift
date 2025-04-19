//
//  OrientationObserver.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 19/04/2025.
//

import SwiftUI
import Combine

class OrientationObserver: ObservableObject {
    @Published var orientation: UIDeviceOrientation = UIDevice.current.orientation

    private var cancellable: AnyCancellable?

    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { _ in
                let newOrientation = UIDevice.current.orientation
                return newOrientation.isValidInterfaceOrientation ? newOrientation : nil
            }
            .assign(to: \.orientation, on: self)
    }

    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        cancellable?.cancel()
    }
}

extension UIDeviceOrientation {
    var isValidInterfaceOrientation: Bool {
        return self == .portrait || self == .landscapeLeft || self == .landscapeRight || self == .portraitUpsideDown
    }

    var isPortrait: Bool {
        self == .portrait || self == .portraitUpsideDown
    }

    var isLandscape: Bool {
        self == .landscapeLeft || self == .landscapeRight
    }
}
