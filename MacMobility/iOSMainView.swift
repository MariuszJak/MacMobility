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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var currentPage: Int = 1
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
    var regularFontSize: CGFloat {
        isIPad ? 24 : 12
    }
    var isIPad: Bool {
        UIDevice.current.localizedModel.contains("iPad")
    }
    var itemsSize: CGFloat {
        isIPad ? 140 : 80
    }
    var itemsSpacing: CGFloat {
        isIPad ? 24 : 6
    }
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
    
    @ViewBuilder
    private var shortcutItemsGridView: some View {
        if isIPad {
            VStack {
                grid(shortcuts: connectionManager.shortcutsList.flatMap { $0.shortcuts }.filter { $0.page == currentPage })
            }
            .padding(.all, 16)
        } else {
            VStack {
                grid(shortcuts: connectionManager.shortcutsList.flatMap { $0.shortcuts }.filter { $0.page == currentPage })
                    .padding(.horizontal, 32)
                Spacer()
            }
            .padding(.all, 16)
        }
    }
    
    func findLargestPage(in shortcuts: [ShortcutObject]) -> Int {
        return shortcuts.max(by: { $0.page < $1.page })?.page ?? 1
    }
    
    func grid(shortcuts: [ShortcutObject]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: itemsSize))], spacing: itemsSpacing) {
            ForEach(0..<21) { index in
                if let test = shortcuts.first(where: { $0.index == index }) {
                    switch test.type {
                    case .shortcut:
                        AnimatedButton {
                            connectionManager.send(shortcut: test)
                        } label: {
                            VStack {
                                ZStack {
                                    if let data = test.imageData,
                                       let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .cornerRadius(20.0)
                                            .frame(width: itemsSize, height: itemsSize)
                                    }
                                    Text(test.title)
                                        .font(.system(size: regularFontSize))
                                        .foregroundStyle(Color.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.all, 3)
                                        .stroke(color: .black)
                                }
                            }
                            .cornerRadius(20.0)
                            .frame(width: itemsSize, height: itemsSize)
                        }
                        .hoverEffect(.highlight)
                   case .app:
                        if let data = test.imageData,
                           let image = UIImage(data: data) {
                            AnimatedButton {
                                connectionManager.send(shortcut: test)
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(20.0)
                                    .frame(width: itemsSize, height: itemsSize)
                            }
                            .hoverEffect(.highlight)
                        }
                    case .utility:
                        if let data = test.imageData,
                           let image = UIImage(data: data) {
                            AnimatedButton {
                                connectionManager.send(shortcut: test)
                            } label: {
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .cornerRadius(20.0)
                                        .frame(width: itemsSize, height: itemsSize)
                                    Text(test.title)
                                        .font(.system(size: regularFontSize))
                                        .foregroundStyle(Color.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.all, 3)
                                        .stroke(color: .black)
                                }
                            }
                            .hoverEffect(.highlight)
                        }
                    case .webpage:
                        if let data = test.imageData,
                           let image = UIImage(data: data) {
                            AnimatedButton {
                                connectionManager.send(shortcut: test)
                            } label: {
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .cornerRadius(20.0)
                                        .frame(width: itemsSize, height: itemsSize)
                                    Text(test.title)
                                        .font(.system(size: regularFontSize))
                                        .foregroundStyle(Color.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.all, 3)
                                        .stroke(color: .black)
                                }
                            }
                            .hoverEffect(.highlight)
                        } else if let data = test.browser?.icon {
                            AnimatedButton {
                                connectionManager.send(shortcut: test)
                            } label: {
                                ZStack {
                                    Image(data)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .cornerRadius(20.0)
                                        .frame(width: itemsSize, height: itemsSize)
                                    Text(test.title)
                                        .font(.system(size: regularFontSize))
                                        .foregroundStyle(Color.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.all, 3)
                                        .stroke(color: .black)
                                }
                            }
                            .hoverEffect(.highlight)
                        }
                    }
                    
                } else {
                    VStack {
                    }
                    .frame(width: itemsSize, height: itemsSize)
                    .background(
                        RoundedRectangle(cornerRadius: 20.0)
                            .fill(.gray.opacity(0.2))
                        
                    )
                }
            }
            .padding(.horizontal)
        }
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
    
    private var disconnectButtonView: some View {
        HStack {
            if connectionManager.pairingStatus == .paired {
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
            Spacer()
            VStack {
                if connectionManager.pairingStatus == .paired {
                    Button("Disconnect") {
                        showsDisconnectAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .padding([.horizontal, .bottom], 32)
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
}

extension UIImage {
    func resizeImage(targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { (context) in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage
    }
}
