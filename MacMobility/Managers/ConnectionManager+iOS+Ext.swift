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

    func getScreenData() {
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
    
    func send(webpageLink: WebpageItem) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(webpageLink) else {
            return
        }
        send(data)
    }
    
    func send(app: AppSendableInfo) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(app) else {
            return
        }
        send(data)
    }
    
    func send(workspace: WorkspaceSendableItem) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(workspace) else {
            return
        }
        send(data)
    }
    
    func send(shortcut: ShortcutObject) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(shortcut) else {
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
                let webpages = webpagesList.flatMap { $0.webpages }
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
                self.webpagesList = webpages.chunked(into: rowCount).map { WebPageListData(webpages: $0) }
            }
            .store(in: &subscriptions)
    }
}

struct RunningAppResponse: Codable {
    let applicationsTitle: String
    let runningApps: [RunningAppData]
}

struct WebpagesResponse: Codable {
    let webpagesTitle: String
    let webpages: [WebpageItem]
}

struct WorkspacesResponse: Codable {
    let workspacesTitle: String
    let workspaces: [WorkspaceSendableItem]
}

struct AppSendableInfo: Identifiable, Codable {
    let id: String
    let name: String
    let path: String
    let imageData: Data?
    
    public init(id: String, name: String, path: String, imageData: Data?) {
        self.id = id
        self.name = name
        self.path = path
        self.imageData = imageData
    }
}

struct WorkspaceSendableItem: Identifiable, Codable {
    var id: String
    let title: String
    let apps: [AppSendableInfo]
    
    public init(id: String, title: String, apps: [AppSendableInfo]) {
        self.id = id
        self.title = title
        self.apps = apps
    }
}

public enum ShortcutType: String, Codable {
    case shortcut
    case app
    case webpage
    case utility
}

public enum UtilityType: String, Codable {
    case commandline
    case multiselection
    case automation
}

enum ChangeType: String, Codable {
    case insert
    case remove
    
    var priority: Int {
        switch self {
        case .insert:
            return 2
        case .remove:
            return 1
        }
    }
}

struct SDiff: Codable {
    var item: ShortcutObject, from: Int?, to: Int?
}

public struct ShortcutObject: Identifiable, Codable {
    public let index: Int?
    public var page: Int
    public let id: String
    public let title: String
    public let path: String?
    public var color: String?
    public var faviconLink: String?
    public let type: ShortcutType
    public let imageData: Data?
    public var browser: Browsers?
    public var scriptCode: String?
    public var utilityType: UtilityType?
    public var objects: [ShortcutObject]?
    public var showTitleOnIcon: Bool?
    
    public init(type: ShortcutType, page: Int, index: Int? = nil, path: String? = nil, id: String,
                title: String, color: String? = nil, faviconLink: String? = nil,
                browser: Browsers? = nil, imageData: Data? = nil, scriptCode: String? = nil,
                utilityType: UtilityType? = nil, objects: [ShortcutObject]? = nil, showTitleOnIcon: Bool = true) {
        self.type = type
        self.page = page
        self.index = index
        self.path = path
        self.id = id
        self.title = title
        self.color = color
        self.imageData = imageData
        self.faviconLink = faviconLink
        self.browser = browser
        self.scriptCode = scriptCode
        self.utilityType = utilityType
        self.objects = objects
        self.showTitleOnIcon = showTitleOnIcon
    }
}

struct ShortcutsResponse: Codable {
    let shortcutTitle: String
    let shortcuts: [ShortcutObject]
}

struct ShortcutsResponseDiff: Codable {
    let shortcutTitle: String
    let shortcutsDiff: [ChangeType: [SDiff]]
}

extension ConnectionManager {
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
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
            
            if let apps = try? JSONDecoder().decode(RunningAppResponse.self, from: data) {
                guard apps.applicationsTitle == "applicationsTitle" else { return }
                self.appList = apps.runningApps.chunked(into: self.rowCount).map { AppListData(apps: $0) }
            }
            
            if let webpages = try? JSONDecoder().decode(WebpagesResponse.self, from: data) {
                guard webpages.webpagesTitle == "webpagesTitle" else { return }
                self.webpagesList = [WebPageListData(webpages: webpages.webpages)]
            }
            
            if let workspaces = try? JSONDecoder().decode(WorkspacesResponse.self, from: data) {
                guard workspaces.workspacesTitle == "workspacesTitle" else { return }
                self.workspacesList = workspaces.workspaces.chunked(into: self.rowCount).map { WorkspacesListData(workspaces: $0) }
            }
            
            if let shortcuts = try? JSONDecoder().decode(ShortcutsResponseDiff.self, from: data) {
                guard shortcuts.shortcutTitle == "shortcutTitleDiff" else { return }
                self.shortcutsDiffList = [ShortcutsDiffListData(shortcutsDiff: shortcuts.shortcutsDiff)]
            }
            
            if let alert = try? JSONDecoder().decode(AlertMessageResponse.self, from: data) {
                guard alert.alertTitle == "alertTitle" else { return }
                self.alert = alert.message
                self.receivedAlert = true
            }
        }
    }
}

struct AlertMessageResponse: Codable {
    let alertTitle: String
    let message: AlertMessage
}


struct AlertMessage: Codable, Equatable {
    let title: String
    let message: String
}

public enum Browsers: String, CaseIterable, Identifiable, Codable {
    public var id: Self { self }
    
    case chrome
    case safari
    
    var icon: String {
        switch self {
        case .chrome:
            return "chrome-logo"
        case .safari:
            return "safari-logo"
        }
    }
}

struct WebpageItem: Identifiable, Codable, Equatable {
    var id: String
    var webpageTitle: String
    var webpageLink: String
    var faviconLink: String?
    var browser: Browsers
}

