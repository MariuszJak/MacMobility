//
//  ConnectionManager+iOS+Ext.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI
import MultipeerConnectivity
import os
import Foundation
import Combine

struct CursorPosition: Codable {
    let width: CGFloat
    let height: CGFloat
}

struct MouseScroll: Codable {
    let offsetX: CGFloat
    let offsetY: CGFloat
}

extension ConnectionManager: ConnectionSenable {
    func send(workspace: WorkspaceControl) {
        self.selectedWorkspace = workspace
        guard !session.connectedPeers.isEmpty,
              let data = workspace.rawValue.data(using: .utf8) else {
            return
        }
        send(data)
    }

    func getAppsList() {
        guard !session.connectedPeers.isEmpty,
              let data = "Connected - send data.".data(using: .utf8) else {
            return
        }
        send(data)
    }

    func send(appName: String) {
        guard !session.connectedPeers.isEmpty,
              let data = appName.data(using: .utf8) else {
            return
        }
        send(data)
    }
    
    func send(position: CursorPosition) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(position) else {
            return
        }
        send(data)
    }
    
    func send(scroll: MouseScroll) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(scroll) else {
            return
        }
        send(data)
    }

    func subscribeForRotationChange() {
        NotificationCenter
            .default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let orientation = UIDevice.current.orientation
                let apps = appList.flatMap { $0.apps }
                switch orientation {
                case .unknown, .portrait, .portraitUpsideDown:
                    self.rowCount = 5
                case .landscapeLeft, .landscapeRight:
                    self.rowCount = 10
                case .faceUp, .faceDown:
                    break
                @unknown default:
                    self.rowCount = 5
                }
                self.appList = apps.chunked(into: rowCount).map { AppListData(apps: $0) }
            }
            .store(in: &subscriptions)
    }
}

extension ConnectionManager {
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let apps = try? JSONDecoder().decode([RunningAppData].self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            let orientation = UIDevice.current.orientation
            switch orientation {
            case .unknown, .portrait, .portraitUpsideDown:
                self.rowCount = 5
            case .landscapeLeft, .landscapeRight:
                self.rowCount = 10
            case .faceUp, .faceDown:
                break
            @unknown default:
                self.rowCount = 5
            }
            self.appList = apps.chunked(into: self.rowCount).map { AppListData(apps: $0) }
        }
    }
}
