//
//
//  Created by Mariusz Jakowienko on 20/01/2024.
//

import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all
    
    let connectionManager = ConnectionManager()
    lazy var iosMainView = iOSMainView(connectionManager: connectionManager)
    var bgTask: UIBackgroundTaskIdentifier = .invalid
    var window: UIWindow?
    var navigationController: UINavigationController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow()
        connectionManager.appState = .foreground
        let mainView = UIHostingController(rootView: iosMainView)
        navigationController = UINavigationController(rootViewController: mainView)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        let lockLandscape: Bool = KeychainManager().retrieve(key: .lockLandscape) ?? Keys.lockLandscape.defaultValue
        AppDelegate.orientationLock = lockLandscape ? .landscape : .all
        
        // Delay to allow window to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            OrientationManager.lock(to: lockLandscape ? .landscape : .portrait)
        }
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        if connectionManager.pairingStatus == .notPaired, let availablePeer = connectionManager.availablePeer {
            let shouldConnect = KeychainManager().retrieve(key: .autoconnect) ?? Keys.autoconnect.defaultValue
            let connectionRequest = try? JSONEncoder().encode(ConnectionRequest(shouldConnect: shouldConnect))
            connectionManager.invitePeer(with: availablePeer, context: connectionRequest)
            if !shouldConnect {
                connectionManager.appState = .foreground
                connectionManager.availablePeer = connectionManager.availablePeer
            }
        }
        connectionManager.appState = .foreground
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        connectionManager.appState = .background
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
