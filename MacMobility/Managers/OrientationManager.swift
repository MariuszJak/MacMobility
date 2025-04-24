//
//  OrientationManager.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 23/04/2025.
//

import UIKit

struct OrientationManager {
    static func lock(to orientation: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = orientation

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        if #available(iOS 16.0, *) {
            var preferences: UIWindowScene.GeometryPreferences
            switch orientation {
            case .landscape:
                preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
            case .portrait:
                preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            default:
                return
            }

            windowScene.requestGeometryUpdate(preferences) { error in
                print("Failed to request geometry update: \(error)")
            }

        } else {
            let value = orientation == .landscape ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }
}
