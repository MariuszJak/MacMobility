//
//
//  Created by Mariusz Jakowienko on 20/01/2024.
//

import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all
    
    let connectionManager = ConnectionManager()
    var bgTask: UIBackgroundTaskIdentifier = .invalid
    var window: UIWindow?
    var navigationController: UINavigationController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow()
        
        let mainView = UIHostingController(rootView: iOSMainView(connectionManager: connectionManager))
        navigationController = UINavigationController(rootViewController: mainView)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        let lockLandscape: Bool = KeychainManager().retrieve(key: .lockLandscape) ?? true
        AppDelegate.orientationLock = lockLandscape ? .landscape : .all
        let value = lockLandscape ? UIInterfaceOrientation.landscapeLeft.rawValue : UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if connectionManager.pairingStatus == .notPaired {
            connectionManager.startBrowsing()
            connectionManager.startAdvertising()
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        bgTask = application.beginBackgroundTask(withName: "KeepMultipeerConnection") {
            self.connectionManager.disconnect()
            application.endBackgroundTask(self.bgTask)
            self.bgTask = .invalid
        }
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
