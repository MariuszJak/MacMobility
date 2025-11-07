//
//  iOSMainView.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI
import Swiftly
import MultipeerConnectivity

extension View {
    func log(_ log: String) -> some View {
        print(log)
        return self
    }
}

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
    
    var is5thOr6yGen: Bool {
        isIPad5thGen() || isIPad6thGen()
    }
    
    var itemsSize: CGFloat {
        if isIPad {
            if is5thOr6yGen {
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
        isIPad ? 21 : 18
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
                        .padding(.top, 14.0)
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        bottomButtonsGridView
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
            VStack(alignment: .leading) {
                grid(shortcuts: connectionManager.shortcutsList.flatMap { $0.shortcuts }.filter { $0.page == currentPage })
            }
            .padding(.vertical, 16)
            .frame(width: orientationObserver.orientation.isLandscape ? (is5thOr6yGen ? 1000.0 : 1100.0) : (isIPadPro13Inch() ? 900.0 : 700.0))
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
    
    func isIPad6thGen() -> Bool {
        let identifier = getDeviceModelIdentifier()
        return identifier == "iPad7,5" || identifier == "iPad7,6" // || identifier == "arm64"
    }
    
    func findLargestPage(in shortcuts: [ShortcutObject]) -> Int {
        return shortcuts.max(by: { $0.page < $1.page })?.page ?? 1
    }
    
    var testSize: CGFloat {
        itemsSpacing
    }
    
    func grid(shortcuts: [ShortcutObject]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: itemsSize), alignment: .leading)], spacing: itemsSpacing) {
            ForEach(0..<21) { index in
                VStack {
                    ZStack {
                        itemView(shortcuts: shortcuts, index: index, size: .init(width: (itemsSize) * ((item(for: index, from: shortcuts)?.size?.width ?? 1.0)) + testSize * ((item(for: index, from: shortcuts)?.size?.width ?? 1.0) - 1),
                                                                                 height: (itemsSize) * ((item(for: index, from: shortcuts)?.size?.height ?? 1.0)) + testSize * ((item(for: index, from: shortcuts)?.size?.height ?? 1.0) - 1)))
                            .frame(
                                width: (itemsSize) * ((item(for: index, from: shortcuts)?.size?.width ?? 1.0)) + testSize * ((item(for: index, from: shortcuts)?.size?.width ?? 1.0) - 1),
                                height: (itemsSize) * ((item(for: index, from: shortcuts)?.size?.height ?? 1.0)) + testSize * ((item(for: index, from: shortcuts)?.size?.height ?? 1.0) - 1),
                            )
                            .if((item(for: index, from: shortcuts)?.size?.width ?? 0) > 1) {
                                $0.padding(.leading, ((itemsSize) * ((item(for: index, from: shortcuts)?.size?.width ?? 1.0)) + testSize * ((item(for: index, from: shortcuts)?.size?.width ?? 1.0) - 1)) * percentageForPadding(of: (item(for: index, from: shortcuts)?.size?.width)))
                            }
                            .if((item(for: index, from: shortcuts)?.size?.height ?? 0) > 1) {
                                $0.padding(.top, ((itemsSize) * ((item(for: index, from: shortcuts)?.size?.height ?? 1.0)) + testSize * ((item(for: index, from: shortcuts)?.size?.height ?? 1.0) - 1)) * percentageForPadding(of: (item(for: index, from: shortcuts)?.size?.height)))
                            }
                    }
                }
                .frame(width: itemsSize, height: itemsSize)
                .if((shortcuts.first(where: { $0.indexes?.contains(index) ?? false }) == nil)) {
                    $0
                        .background(
                            PlusButtonView(itemSize: .init(width: itemsSize, height: itemsSize))
                        )
                }
            }
            .padding(.horizontal)
        }
    }
    
    func percentageForPadding(of value: CGFloat?) -> CGFloat {
        guard let value else { return 1.0 }
        if value == 2 {
            return 0.52
        } else if value == 3 {
            return 0.7
        } else {
            return 1.0
        }
    }
    
    @ViewBuilder
    func itemView(shortcuts: [ShortcutObject], index: Int, size: CGSize) -> some View {
        if let shortcut = shortcuts.first(where: { $0.indexes?.first == index }) {
            switch shortcut.type {
            case .shortcut:
                AnimatedButton {
                    connectionManager.send(shortcut: shortcut)
                } label: {
                    VStack {
                        ZStack {
                            if let data = shortcut.imageData,
                               let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .cornerRadius(20.0)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 20.0)
                                    )
                            }
                            if shortcut.showTitleOnIcon ?? true {
                                Text(shortcut.title)
                                    .font(.system(size: regularFontSize))
                                    .multilineTextAlignment(.center)
                                    .padding(.all, 3)
                                    .lineLimit(3)
                                    .outlinedText()
                                    .foregroundStyle(Color.white)
                            }
                        }
                    }
                }
            case .html:
                if let scriptCode = shortcut.scriptCode {
                    HTMLView(htmlContent: """
                    \(scriptCode)
                    """)
                    .cornerRadius(20.0)
                    .hoverEffect(.highlight)
                }
           case .app:
                if let data = shortcut.imageData,
                   let image = UIImage(data: data) {
                    AnimatedButton {
                        connectionManager.send(shortcut: shortcut)
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaleEffect(1.2)
                            .aspectRatio(contentMode: .fill)
                            .cornerRadius(20.0)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 20.0)
                            )
                    }
                    .hoverEffect(.highlight)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red)
                }
            case .utility:
                if let data = shortcut.imageData,
                   let image = UIImage(data: data) {
                    AnimatedButton {
                        connectionManager.send(shortcut: shortcut)
                    } label: {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .cornerRadius(20.0)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 20.0)
                                )
                            if shortcut.showTitleOnIcon ?? true {
                                Text(shortcut.title)
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
                if let data = shortcut.imageData,
                   let image = UIImage(data: data) {
                    AnimatedButton {
                        connectionManager.send(shortcut: shortcut)
                    } label: {
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .cornerRadius(20.0)
                                .frame(width: size.width, height: size.height)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 20.0)
                                )
                            if shortcut.showTitleOnIcon ?? true {
                                Text(shortcut.title)
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
                } else if let data = shortcut.browser?.icon {
                    AnimatedButton {
                        connectionManager.send(shortcut: shortcut)
                    } label: {
                        ZStack {
                            Image(data)
                                .resizable()
                                .scaleEffect(1.1)
                                .aspectRatio(contentMode: .fill)
                                .cornerRadius(20.0)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 20.0)
                                )
                            if shortcut.showTitleOnIcon ?? true {
                                Text(shortcut.title)
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
            case .control:
                if shortcut.path == "control:horizontal-slider" {
                    VolumeContainerView(item: shortcut) { value in
                        if let scriptCode = shortcut.scriptCode {
                            let updatedScript = String(format: scriptCode, value)
                            var tmp = shortcut
                            tmp.scriptCode = updatedScript
                            connectionManager.send(shortcut: tmp)
                        }
                    }
                } else if shortcut.path == "control:rotary-knob" {
                    RotaryKnob(item: shortcut, title: shortcut.title) { value in
                        if let scriptCode = shortcut.scriptCode {
                            let updatedScript = String(format: scriptCode, value)
                            var tmp = shortcut
                            tmp.scriptCode = updatedScript
                            connectionManager.send(shortcut: tmp)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 20.0)
                        .fill(.blue)
                }
            }
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
    
    func item(for index: Int, from shortcuts: [ShortcutObject]) -> ShortcutObject? {
        shortcuts.first(where: { $0.indexes?.first == index })
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
    
    private var bottomButtonsGridView: some View {
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
        .padding(.bottom, 2)
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
