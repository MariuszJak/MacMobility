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
    @Published var availablePeer: MCPeerID?
    @Published var connectedPeerName: String?
    @Published var receivedInvite: Bool = false
    @Published var receivedAlert: Bool = false
    @Published var receivedInviteFrom: MCPeerID?
    @Published var invitationHandler: ((Bool, MCSession?) -> Void)?
    @Published var selectedWorkspace: WorkspaceControl?
    @Published var pairingStatus: PairingStatus = .notPaired
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
        availablePeer != nil && pairingStatus == .notPaired
    }

    @Published public var appList: [AppListData] = []
    @Published public var webpagesList: [WebPageListData] = []
    @Published public var workspacesList: [WorkspacesListData] = []
    @Published public var shortcutsList: [ShortcutsListData] = []
    @Published public var shortcutsDiffList: [ShortcutsDiffListData] = []
    @Published public var alert: AlertMessage?
    @Published public var isInitialLoading: Bool = true
    public var rowCount = 4

    override init() {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
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
                                    if sdiff.item.id == object.id {
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
        availablePeer = nil
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

extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.isInitialLoading = true
            self.receivedInvite = true
            self.receivedInviteFrom = peerID
            self.invitationHandler = invitationHandler
        }
    }
}

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        log.error("ServiceBrowser didNotStartBrowsingForPeers: \(String(describing: error))")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if let availablePeer = self.availablePeer {
                self.availablePeer = availablePeer
            } else {
                self.availablePeer = peerID
                self.connectedPeerName = peerID.displayName
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        guard availablePeer == peerID else { return }
        availablePeer = nil
    }
}

extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.pairingStatus = state == .connected ? .paired : .notPaired
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
