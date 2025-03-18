//
//  iOSMainView.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI
import Swiftly

struct Preferences {
    enum Key {
        static let didSeenDependencyScreens = "didSeenDependencyScreens"
    }
}

struct AppListData: Identifiable {
    var id: String { UUID().uuidString }
    var apps: [RunningAppData]
}

struct WebPageListData: Identifiable {
    var id: String { UUID().uuidString }
    var webpages: [WebpageItem]
}

struct WorkspacesListData: Identifiable {
    var id: String { UUID().uuidString }
    var workspaces: [WorkspaceSendableItem]
}

struct ShortcutsListData: Identifiable {
    var id: String { UUID().uuidString }
    var shortcuts: [ShortcutObject]
}

struct WorkSpaceControlItem: Identifiable {
    var id: String { UUID().uuidString }
    let title: String
    let icon: UIImage?
    let action: () -> Void
}

struct iOSMainView: View {
    @UserDefault(Preferences.Key.didSeenDependencyScreens) var didSeenDependencyScreens = false
    @StateObject var connectionManager = ConnectionManager()
    @State var startPos: CGPoint = .zero
    @State var isSwipping = true
    @State var showQRScaner = false
    @State var showDependencyScreen = false
    @State private var trigger = false
    @State private var showsWorkspaces = false
    @State private var showsDisconnectAlert = false
    var workspaceControlItems: [WorkSpaceControlItem] {
        [
            .init(title: "Prev", icon: .init(named: "prev-btn"), action: {
                connectionManager.send(workspace: .prev)
            }),
            .init(title: "Next", icon: .init(named: "next-btn"), action: {
                connectionManager.send(workspace: .next)
            })
        ]
    }
    var spacing: CGFloat = 12.0

    var body: some View {
        VStack {
            qrCodeScannerButtonView
            ZStack {
                if connectionManager.pairingStatus == .paired  {
                    shortcutItemsGridView
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        disconnectButtonView
                    }
                }
                
            }
        }
        .alert("Received invitation from \(connectionManager.receivedInviteFrom?.displayName ?? "")",
               isPresented: $connectionManager.receivedInvite) {
            alertView
        }
        .sheet(isPresented: $showQRScaner) {
            qrCodeScannerView
        }
        .sheet(isPresented: $showDependencyScreen, onDismiss: {
            didSeenDependencyScreens = true
        }, content: {
            MacOSAppDependencyScreen()
                .if(!didSeenDependencyScreens) {
                    $0.interactiveDismissDisabled()
                }
        })
        .onAppear {
            connectionManager.startAdvertising()
            connectionManager.startBrowsing()
            if !didSeenDependencyScreens {
                showDependencyScreen = true
            }
        }
        .onChange(of: connectionManager.pairingStatus) { pairingStatus in
            handlePairingStatus(with: pairingStatus)
        }
        .ignoresSafeArea()
        .animation(.easeInOut, value: $connectionManager.pairingStatus.wrappedValue)
        .padding(.horizontal)
    }
    
    func handlePairingStatus(with pairingStatus: PairingStatus) {
        switch pairingStatus {
        case .paired:
            connectionManager.stopAdvertising()
            connectionManager.stopBrowsing()
            connectionManager.getScreenData()
        case .notPaired:
            connectionManager.appList.removeAll()
            connectionManager.webpagesList.removeAll()
            connectionManager.workspacesList.removeAll()
            connectionManager.shortcutsList.removeAll()
            connectionManager.startAdvertising()
            connectionManager.startBrowsing()
            connectionManager.receivedInvite = false
        case .pairining:
            break
        }
    }
    
    @ViewBuilder
    private var qrCodeScannerView: some View {
        QRCodeScanner() { code in
            showQRScaner = false
            if let availablePeer = connectionManager.availablePeer {
                let data = code.data(using: .utf8)
                connectionManager.invitePeer(with: availablePeer, context: data)
            }
        }
    }
    
    @ViewBuilder
    private var alertView: some View {
        Button("Accept") {
            guard let invitationHandler = connectionManager.invitationHandler else {
                return
            }
            invitationHandler(true, connectionManager.session)
        }
        Button("Reject") {
            guard let invitationHandler = connectionManager.invitationHandler else {
                return
            }
            invitationHandler(false, nil)
        }
    }
    
    @ViewBuilder
    private var workspaceControls: some View {
        if connectionManager.pairingStatus == .paired {
            VStack(alignment: .leading, spacing: spacing) {
                Divider()
                HStack {
                    Text("Workspaces")
                    Spacer()
                    Button(showsWorkspaces ? "Hide" : "Show") {
                        showsWorkspaces.toggle()
                    }
                }
                HStack(spacing: spacing) {
                    ForEach(workspaceControlItems) { item in
                        VStack(spacing: .zero) {
                            if let image = item.icon {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(6.0)
                                    .frame(width: 74.0, height: 74.0)
                                    .opacity(0.8)
                                Text(item.title)
                                    .font(.caption2)
                            }
                        }
                        .onTapGesture {
                            item.action()
                        }
                    }
                    Spacer()
                }
                .opacity(showsWorkspaces ? 1.0 : 0.0)
                .if(!showsWorkspaces) {
                    $0.frame(height: 0.0)
                }
                Divider()
                    .padding(.bottom, 6.0)
            }
        }
    }
    
    private var disconnectButtonView: some View {
        HStack {
            Spacer()
            VStack {
                if connectionManager.pairingStatus == .paired {
                    Button("Disconnect") {
                        showsDisconnectAlert = true
                    }
                    .foregroundStyle(.red)
                    .padding(.bottom, 32)
                }
            }
        }
        .alert("Are you sure you want to disconnect?",
               isPresented: $showsDisconnectAlert) {
            HStack {
                Button("Disconnect", role: .destructive) {
                    connectionManager.disconnect()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    @ViewBuilder
    private var qrCodeScannerButtonView: some View {
        if connectionManager.pairingStatus == .notPaired {
            VStack(spacing: 16.0) {
                Spacer()
                Button {
                    showQRScaner = true
                } label: {
                    VStack {
                        Image("ios-qr-scanner")
                            .resizable()
                            .frame(width: 56.0, height: 56.0)
                        Text("Tap to scan QR code")
                            .font(.system(size: 12.0))
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                Button {
                    showDependencyScreen = true
                } label: {
                    Text("Do you have MacOS app? Tap to download")
                        .font(.system(size: 12.0))
                        .foregroundStyle(.white)
                        .opacity(0.6)
                }
            }
            .frame(height: UIScreen.main.bounds.height - 106.0)
        }
    }
    
    private var appGridView: some View {
        VStack {
            HStack {
                Text("Running apps")
                    .font(.system(size: 18.0, weight: .medium))
                    .padding([.vertical, .leading], 4.0)
                Spacer()
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading) {
                    ForEach($connectionManager.appList) { item in
                        HStack(alignment: .top) {
                            ForEach(Array(item.apps.wrappedValue.enumerated()), id: \.offset) { object in
                                VStack {
                                    if let data = object.element.imageData,
                                       let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .cornerRadius(6.0)
                                            .frame(width: 62.0, height: 62.0)
                                        Text(object.element.title)
                                            .font(.caption2)
                                            .frame(maxWidth: 60.0)
                                            .multilineTextAlignment(.center)
                                    } else {
                                        Image("Empty")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .cornerRadius(6.0)
                                            .frame(width: 74.0, height: 74.0)
                                        Text(object.element.title)
                                            .font(.caption2)
                                            .frame(maxWidth: 60.0)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .onTapGesture {
                                    connectionManager.send(appName: object.element.title)
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var webItemsGridView: some View {
        VStack {
            HStack {
                Text("Web links")
                    .font(.system(size: 18.0, weight: .medium))
                    .padding([.vertical, .leading], 4.0)
                Spacer()
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading) {
                    ForEach($connectionManager.webpagesList) { item in
                        HStack(alignment: .top) {
                            ForEach(Array(item.webpages.wrappedValue.enumerated()), id: \.offset) { object in
                                Button {
                                    connectionManager.send(webpageLink: object.element)
                                } label: {
                                    VStack {
                                        if let favlink = object.element.faviconLink, let url = URL(string: favlink) {
                                            SwiftlyImage(url: url, placeholder: .init(named: "Empty"))
                                                .cornerRadius(6.0)
                                                .frame(width: 74, height: 74)
                                        } else {
                                            Image(object.element.browser.icon)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .cornerRadius(6.0)
                                                .frame(width: 74, height: 74)
                                        }
                                        Text(object.element.webpageTitle)
                                            .foregroundStyle(Color.white)
                                            .font(.caption2)
                                            .frame(maxWidth: 74)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private var workspaceItemsGridView: some View {
        VStack {
            HStack {
                Text("Workspaces")
                    .font(.system(size: 18.0, weight: .medium))
                    .padding([.vertical, .leading], 4.0)
                Spacer()
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    ForEach($connectionManager.workspacesList) { item in
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 6) {
                                ForEach(Array(item.workspaces.wrappedValue.enumerated()), id: \.offset) { object in
                                    VStack(alignment: .leading){
                                        Text(object.element.title)
                                            .font(.caption2)
                                            .multilineTextAlignment(.center)
                                        grid(for: object.element.apps)
                                        Button("Launch All") {
                                            connectionManager.send(workspace: object.element)
                                        }
                                    }
                                    .frame(width: 200)
                                    .padding(.all, 10.0)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                                Spacer()
                        }
                    }
                }
            }
        }
    }
    
    @State var currentPage: Int = 1
    
    private var shortcutItemsGridView: some View {
        VStack {
            grid(shortcuts: connectionManager.shortcutsList.flatMap { $0.shortcuts }.filter { $0.page == currentPage })
                .padding(.bottom, 24)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(1..<findLargestPage(in: connectionManager.shortcutsList.flatMap(\.shortcuts)) + 1, id: \.self) { page in
                        Button("Page \(page)") {
                            currentPage = page
                        }
                        .padding()
                    }
                }
            }
        }
        .padding(.all, 16)
    }
    
    func findLargestPage(in shortcuts: [ShortcutObject]) -> Int {
        return shortcuts.max(by: { $0.page < $1.page })?.page ?? 1
    }
    
    func grid(shortcuts: [ShortcutObject]) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                ForEach(0..<21) { index in
                    if let test = shortcuts.first(where: { $0.index == index }) {
                        switch test.type {
                        case .shortcut:
                            VStack {
                                ZStack {
                                    Text(test.title)
                                        .font(.system(size: 12))
                                        .multilineTextAlignment(.center)
                                        .padding(.all, 3)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 20.0)
                                    .fill(Color(hex: test.color ?? ""))
                                
                            )
                            .onTapGesture {
                                connectionManager.send(shortcut: test)
                            }
                        case .app:
                            if let data = test.imageData,
                               let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(20.0)
                                    .frame(width: 80, height: 80)
                                    .onTapGesture {
                                        connectionManager.send(shortcut: test)
                                    }
                            }
                        case .webpage:
                            if let data = test.imageData,
                               let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(20.0)
                                    .frame(width: 80, height: 80)
                                    .onTapGesture {
                                        connectionManager.send(shortcut: test)
                                    }
                            } else if let data = test.browser?.icon {
                                Image(data)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(20.0)
                                    .frame(width: 80, height: 80)
                                    .onTapGesture {
                                        connectionManager.send(shortcut: test)
                                    }
                            }
                        }
                        
                    } else {
                        VStack {
                        }
                        .frame(width: 80, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 20.0)
                                .fill(.gray.opacity(0.2))
                            
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollDisabled(true)
    }
    
    @ViewBuilder
    func grid(for apps: [AppSendableInfo]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 4) {
            ForEach(apps) { app in
                if let data = app.imageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .cornerRadius(6.0)
                        .frame(width: 62.0, height: 62.0)
                        .onTapGesture {
                            connectionManager.send(app: app)
                        }
                }
            }
        }
        .padding(.bottom, 20.0)
    }
}
