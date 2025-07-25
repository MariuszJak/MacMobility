//
//  ConnectionManager.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI
import MultipeerConnectivity
import os
import Foundation
import Combine

enum PairingStatus: Equatable {
    case notPaired
    case paired
    case pairining
}

struct RunningAppData: Codable, Equatable, Identifiable {
    var id: String { title }
    let title: String
    let imageData: Data?
}

enum AppState {
    case foreground
    case background
}

class ConnectionManager: NSObject, ObservableObject {
    @Published var availablePeerWithName: (MCPeerID?, String)?
    @Published var connectedPeerName: String?
    @Published var receivedInvite: Bool = false
    @Published var receivedAlert: Bool = false
    @Published var receivedInviteWithNameFrom: (MCPeerID, String)?
    @Published var receivedStartStreamCommand: Bool = false
    @Published var invitationHandler: ((Bool, MCSession?) -> Void)?
    @Published var selectedWorkspace: WorkspaceControl?
    @Published var pairingStatus: PairingStatus = .notPaired
    public var ipAddress: String?
    public var appState: AppState?
    public let serviceType = "magic-trackpad"
    public var myPeerId: MCPeerID = {
        return MCPeerID(displayName: UIDevice.current.name)
    }()
    
    public let serviceAdvertiser: MCNearbyServiceAdvertiser
    public let serviceBrowser: MCNearbyServiceBrowser
    public let session: MCSession
    public let log = Logger()
    public var runningApps: [RunningAppData] = []
    public var observers = [NSKeyValueObservation]()
    public var subscriptions = Set<AnyCancellable>()
    public var isUpdating = false
    public var isConnecting: Bool {
        availablePeerWithName != nil && pairingStatus == .notPaired
    }

    @Published public var appList: [AppListData] = []
    @Published public var webpagesList: [WebPageListData] = []
    @Published public var workspacesList: [WorkspacesListData] = []
    @Published public var shortcutsList: [ShortcutsListData] = []
    @Published public var shortcutsDiffList: [ShortcutsDiffListData] = []
    @Published public var assignedPagesToApps: [AssignedAppsToPages] = []
    @Published public var pageToFocus: AssignedAppsToPages?
    @Published public var alert: AlertMessage?
    @Published public var isInitialLoading: Bool = true
    public var rowCount = 4

    override init() {
        let screen = UIScreen.main
        let size = screen.bounds.size
        let scale = screen.scale
        
        let width = Int((size.width * scale) * 0.5)
        let height = Int((size.height * scale) * 0.5)
        let screenResolution = "\(height),\(width)"
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: ["screenResolution": "\(screenResolution)", "name": UIDevice.current.name], serviceType: serviceType)
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)

        super.init()

        session.delegate = self
        serviceAdvertiser.delegate = self
        serviceBrowser.delegate = self

        subscribeForRotationChange()
        
        // For debugging, only for simulator
//        #if DEBUG
//        pairingStatus = .paired
//        isInitialLoading = false
//        #endif
        
        $shortcutsDiffList
            .receive(on: RunLoop.main)
            .sink { diffs in
                let test = diffs.flatMap { $0.shortcutsDiff }.sorted { $0.key.priority < $1.key.priority }
                test.forEach { key, value in
                    switch key {
                    case .insert:
                        self.shortcutsList.append(.init(shortcuts: value.map { $0.item }))
                    case .remove:
                        value.forEach { sdiff in
                            self.shortcutsList.enumerated().forEach { (at, item) in
                                item.shortcuts.enumerated().forEach { index, object in
                                    if sdiff.item.id == object.id && sdiff.item.page == object.page {
                                        self.shortcutsList[at].shortcuts.remove(at: index)
                                    }
                                }
                            }
                        }
                    }
                }
        }.store(in: &subscriptions)
    }

    deinit {
        stopAdvertising()
        stopBrowsing()
    }
    
    func connectToIPIfNeeded() {
        let autoconnect = KeychainManager().retrieve(key: .autoconnectToExternalDisplay) ?? Keys.autoconnectToExternalDisplay.defaultValue
        guard ipAddress != nil && autoconnect else {
            return
        }
        send(serverReconnect: .init(reconnect: true))
    }
    
    func startAdvertising() {
        serviceAdvertiser.startAdvertisingPeer()
    }
    
    func stopAdvertising() {
        serviceAdvertiser.stopAdvertisingPeer()
    }
    
    func startBrowsing() {
        serviceBrowser.startBrowsingForPeers()
    }
    
    func stopBrowsing() {
        serviceBrowser.stopBrowsingForPeers()
        availablePeerWithName = nil
    }
    
    func toggleAdvertising() {
        switch pairingStatus {
        case .notPaired:
            startAdvertising()
        case .pairining:
            break
        case .paired:
            stopAdvertising()
        }
    }
    
    func invitePeer(with peer: MCPeerID, context: Data? = nil) {
        serviceBrowser.invitePeer(peer, to: session, withContext: context, timeout: 30)
    }
    
    func disconnect() {
        session.disconnect()
        pairingStatus = .notPaired
        toggleAdvertising()
        isInitialLoading = true
    }
}

struct ConnectionRequest: Codable {
    let shouldConnect: Bool
}

struct DeviceName: Codable {
    let name: String
}

extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        if let context, let deviceName = try? JSONDecoder().decode(DeviceName.self, from: context) {
            DispatchQueue.main.async {
                self.isInitialLoading = true
                self.receivedInvite = true
                self.receivedInviteWithNameFrom = (peerID, deviceName.name)
                self.invitationHandler = invitationHandler
            }
        } else {
            DispatchQueue.main.async {
                self.isInitialLoading = true
                self.receivedInvite = true
                self.receivedInviteWithNameFrom = (peerID, peerID.displayName)
                self.invitationHandler = invitationHandler
            }
        }
    }
}

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        log.error("ServiceBrowser didNotStartBrowsingForPeers: \(String(describing: error))")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if let availablePeerWithName = self.availablePeerWithName {
                self.availablePeerWithName = availablePeerWithName
            } else {
                if !peerID.displayName.contains("iPad") && !peerID.displayName.contains("iPhone") {
                    let name = info?["name"] ?? peerID.displayName
                    self.availablePeerWithName = (peerID, name)
                    self.connectedPeerName = name
                }
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        guard availablePeerWithName?.0 == peerID else { return }
        availablePeerWithName = nil
    }
}

extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            let shouldConnect = KeychainManager().retrieve(key: .autoconnect) ?? Keys.autoconnect.defaultValue
            KeychainManager().save(key: .reconnect, value: self.pairingStatus == .paired && shouldConnect)
            self.pairingStatus = state == .connected ? .paired : .notPaired
            if state == .notConnected, self.receivedStartStreamCommand {
                self.receivedStartStreamCommand = false
            }
            self.toggleAdvertising()
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        log.error("Receiving streams is not supported")
    }

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        log.error("Receiving resources is not supported")
    }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        log.error("Receiving resources is not supported")
    }
}
