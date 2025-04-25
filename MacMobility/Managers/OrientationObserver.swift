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
    var lockLandscape: Bool {
        KeychainManager().retrieve(key: .lockLandscape) ?? Keys.lockLandscape.defaultValue
    }
    
    var isValidInterfaceOrientation: Bool {
        if lockLandscape { return true }
        return self == .portrait || self == .landscapeLeft || self == .landscapeRight || self == .portraitUpsideDown
    }

    var isPortrait: Bool {
        self == .portrait || self == .portraitUpsideDown
    }

    var isLandscape: Bool {
        if lockLandscape { return true }
        return self == .landscapeLeft || self == .landscapeRight
    }
}
