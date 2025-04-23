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

        let value = orientation == .landscape ? UIInterfaceOrientation.landscapeLeft.rawValue : UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }
}
