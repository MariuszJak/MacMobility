//
//  iOSMainView.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI
import Swiftly
import MultipeerConnectivity

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

struct ShortcutsDiffListData: Identifiable {
    var id: String { UUID().uuidString }
    var shortcutsDiff: [ChangeType: [SDiff]]
}

struct WorkSpaceControlItem: Identifiable {
    var id: String { UUID().uuidString }
    let title: String
    let icon: UIImage?
    let action: () -> Void
}

struct iOSMainView: View {
    @Environment(\.scenePhase) private var scenePhase
    @UserDefault(Preferences.Key.didSeenDependencyScreens) var didSeenDependencyScreens = false

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @State var currentPage: Int = 1
    @StateObject var connectionManager: ConnectionManager
    @StateObject private var orientationObserver = OrientationObserver()
    @State var startPos: CGPoint = .zero
    @State var isSwipping = true
    @State var showQRScaner = false
    @State var showDependencyScreen = false
    @State private var trigger = false
    @State private var showsWorkspaces = false
    @State private var showsDisconnectAlert = false
    @State private var showsAppSettings = false
    
    @State private var connectionAfterTutorial: (() -> Void)?

    var spacing: CGFloat = 12.0
    var regularFontSize: CGFloat {
        isIPad ? 24 : 12
    }
    var isIPad: Bool {
        UIDevice.current.localizedModel.contains("iPad")
    }
    var itemsSize: CGFloat {
        if isIPad {
            if isIPad5thGen() {
                return (orientationObserver.orientation.isLandscape ? 120 : 90)
            } else if isIPadPro13Inch() {
                return orientationObserver.orientation.isLandscape ? 140 : 110
            } else if isIPadPro11Inch() {
                return orientationObserver.orientation.isLandscape ? 140 : 90
            } else {
                return (orientationObserver.orientation.isLandscape ? 140 : (isIPadPro13Inch() ? 110 : 90))
            }
        } else {
           return 80
        }
    }
    var itemsSpacing: CGFloat {
        isIPad ? 21 : 8
    }
    
    init(connectionManager: ConnectionManager) {
        self._connectionManager = .init(wrappedValue: connectionManager)
    }
        
    var body: some View {
        VStack {
            qrCodeScannerButtonView
            ZStack {
                if connectionManager.pairingStatus == .paired  {
                    shortcutItemsGridView
                        .padding(.top, 38.0)
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        disconnectButtonView
                    }
                }
                if connectionManager.pairingStatus == .pairining || connectionManager.pairingStatus == .paired {
                    if connectionManager.isInitialLoading {
                        FullscreenLoadingView(isAnimating: .constant(true))
                    }
                }
            }
            .fullScreenCover(isPresented: $connectionManager.receivedStartStreamCommand) {
                if let ipAddress = connectionManager.ipAddress {
                    StreamView(serverIP: ipAddress)
                }
            }
            .fullScreenCover(isPresented: $showsAppSettings) {
                SettingsView(isPresented: $showsAppSettings)
            }
            .fullScreenCover(isPresented: $connectionManager.showsConnectionView) {
                if let availablePeerWithName = connectionManager.availablePeerWithName, let availablePeer = availablePeerWithName.0 {
                    PairingView(
                        connectionManager: connectionManager,
                        isPresented: $connectionManager.showsConnectionView,
                        deviceName: availablePeerWithName.1) {
                            let context = try? JSONEncoder().encode(ConnectionRequest(shouldConnect: true))
                            connectionManager.isInitialLoading = true
                            connectionManager.invitePeer(with: availablePeer, context: context)
                            connectionManager.showsConnectionView = false
                        } onReject: {
                            connectionManager.showsConnectionView = false
                        }
                } else {
                    NoPairingDevicesView(isPresented: $connectionManager.showsConnectionView)
                }
            }
        }
        .alert("Commandline Response", isPresented: $connectionManager.receivedAlert) {
            Button("Close") {
                connectionManager.receivedAlert = false
            }
        } message: {
            VStack {
                if let description = connectionManager.alert?.message {
                    Text(description)
                }
            }
        }
        .onReceive(connectionManager.$availablePeerWithName) { availablePeer in
            if availablePeer != nil {
                if didSeenDependencyScreens &&
                    connectionManager.appState == .foreground {
                    connectionManager.showsConnectionView = true
                } else {
                    connectionAfterTutorial = {
                        connectionManager.showsConnectionView = true
                    }
                }
            }
        }
        .onChange(of: connectionManager.pageToFocus) { pageToFocus in
            currentPage = pageToFocus?.page ?? 1
        }
        .sheet(isPresented: $showQRScaner) {
            qrCodeScannerView
        }
        .sheet(isPresented: $showDependencyScreen, onDismiss: {
            didSeenDependencyScreens = true
        }, content: {
            AppDependencyScreen() {
                connectionAfterTutorial?()
            }
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
            .padding(.vertical, 16)
            .frame(width: orientationObserver.orientation.isLandscape ? (isIPad5thGen() ? 1000.0 : 1100.0) : (isIPadPro13Inch() ? 900.0 : 700.0))
        } else {
            VStack {
                grid(shortcuts: connectionManager.shortcutsList.flatMap { $0.shortcuts }.filter { $0.page == currentPage })
                    .frame(width: orientationObserver.orientation.isLandscape ? 670.0 : 300)
                Spacer()
            }
            .padding(.all, 16)
        }
    }
    
    func getDeviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            ptr in String(cString: UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self))
        }
    }

    func isIPadPro13Inch() -> Bool {
        let identifier = getDeviceModelIdentifier()
        return identifier == "iPad16,3" || identifier == "iPad16,4" // || identifier == "arm64"
    }

    func isIPadPro11Inch() -> Bool {
        let identifier = getDeviceModelIdentifier()
        return identifier == "iPad16,1" || identifier == "iPad16,2" // || identifier == "arm64"
    }
    
    func isIPad5thGen() -> Bool {
        let identifier = getDeviceModelIdentifier()
        return identifier == "iPad6,11" || identifier == "iPad6,12" // || identifier == "arm64"
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
                                            .clipShape(
                                                RoundedRectangle(cornerRadius: 20.0)
                                            )
                                    }
                                    if test.showTitleOnIcon ?? true {
                                        Text(test.title)
                                            .font(.system(size: regularFontSize))
                                            .multilineTextAlignment(.center)
                                            .padding(.all, 3)
                                            .lineLimit(3)
                                            .outlinedText()
                                            .foregroundStyle(Color.white)
                                    }
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
                                    .scaleEffect(1.2)
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(20.0)
                                    .frame(width: itemsSize, height: itemsSize)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 20.0)
                                    )
                            }
                            .hoverEffect(.highlight)
                        } else {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red)
                                .frame(width: itemsSize, height: itemsSize)
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
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 20.0)
                                        )
                                    if test.showTitleOnIcon ?? true {
                                        Text(test.title)
                                            .font(.system(size: regularFontSize))
                                            .multilineTextAlignment(.center)
                                            .padding(.all, 3)
                                            .lineLimit(3)
                                            .outlinedText()
                                            .foregroundStyle(Color.white)
                                    }
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
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 20.0)
                                        )
                                    if test.showTitleOnIcon ?? true {
                                        Text(test.title)
                                            .font(.system(size: regularFontSize))
                                            .multilineTextAlignment(.center)
                                            .padding(.all, 3)
                                            .lineLimit(3)
                                            .outlinedText()
                                            .foregroundStyle(Color.white)
                                    }
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
                                        .scaleEffect(1.1)
                                        .aspectRatio(contentMode: .fill)
                                        .cornerRadius(20.0)
                                        .frame(width: itemsSize, height: itemsSize)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 20.0)
                                        )
                                    if test.showTitleOnIcon ?? true {
                                        Text(test.title)
                                            .font(.system(size: regularFontSize))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                            .outlinedText()
                                            .foregroundStyle(Color.white)
                                    }
                                }
                            }
                            .hoverEffect(.highlight)
                        }
                    case .html:
                        if let scriptCode = test.scriptCode {
                            HTMLCPUView(htmlContent: """
                            \(scriptCode)
                            """)
                            .cornerRadius(20.0)
                            .frame(width: itemsSize, height: itemsSize)
                        }
                    }
                } else {
                    PlusButtonView(itemSize: .init(width: itemsSize, height: itemsSize))
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
            connectionManager.shortcutsDiffList.removeAll()
            connectionManager.startAdvertising()
            connectionManager.startBrowsing()
            connectionManager.showsConnectionView = false
        case .pairining:
            break
        }
    }
    
    @ViewBuilder
    private var qrCodeScannerView: some View {
        QRCodeScanner() { code in
            showQRScaner = false
            if let availablePeer = connectionManager.availablePeerWithName?.0 {
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
                    HStack(spacing: 3.0) {
                        ForEach(1..<findLargestPage(in: connectionManager.shortcutsList.flatMap(\.shortcuts)) + 1, id: \.self) { page in
                            PrimaryButton(title: "Page: \(page)", isSelected: page == currentPage) {
                                currentPage = page
                            }
                            .animation(.easeInOut, value: currentPage)
                            .hoverEffect(.highlight)
                        }
                    }
                }
            }
            Spacer()
            VStack {
                HStack {
                    Button(action: {
                        showsAppSettings = true
                    }) {
                        Image(systemName: "gear")
                            .imageScale(.large)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8.0)
                    .hoverEffect(.highlight)
                    if connectionManager.pairingStatus == .paired {
                        Button {
                            showsDisconnectAlert = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .hoverEffect(.highlight)
                    }
                }
            }
        }
        .padding(.bottom, 28)
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
                VStack {
                    Text("Check for connection")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 16.0)
                    Image(.tapToConnect)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 90, height: 90)
                        .padding(.bottom, 26.0)
                    Text("Tap to check available connection")
                        .font(.system(size: 16.0))
                }
                .onTapGesture {
                    connectionManager.showsConnectionView = true
                }
                HStack {
                    Text("Do you have companion app? ")
                        .font(.system(size: 12, weight: .regular))
                    Text("Tap to Learn More")
                        .font(.system(size: 12, weight: .regular))
                        .underline()
                        .onTapGesture {
                            showDependencyScreen = true
                        }
                }
            }
            .frame(height: UIScreen.main.bounds.height - 106.0)
        }
    }
}

