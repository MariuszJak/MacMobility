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
    @State var showsConnectionView = false
    
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
            return (orientationObserver.orientation.isLandscape ? 140 : (isIPadPro13Inch() ? 110 : 90))
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
            .fullScreenCover(isPresented: $showsConnectionView) {
                if let availablePeerWithName = connectionManager.availablePeerWithName, let availablePeer = availablePeerWithName.0 {
                    PairingView(
                        connectionManager: connectionManager,
                        isPresented: $showsConnectionView,
                        deviceName: availablePeerWithName.1) {
                            let context = try? JSONEncoder().encode(ConnectionRequest(shouldConnect: true))
                            connectionManager.isInitialLoading = true
                            connectionManager.invitePeer(with: availablePeer, context: context)
                            showsConnectionView = false
                        } onReject: {
                            showsConnectionView = false
                        }
                } else {
                    NoPairingDevicesView(isPresented: $showsConnectionView)
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
                    showsConnectionView = true
                } else {
                    connectionAfterTutorial = {
                        showsConnectionView = true
                    }
                }
            }
        }
        .alert("Received invitation from \(connectionManager.receivedInviteWithNameFrom?.1 ?? "")",
               isPresented: $connectionManager.receivedInvite) {
            alertView
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
            .frame(width: orientationObserver.orientation.isLandscape ? 1100.0 : (isIPadPro13Inch() ? 900.0 : 700.0))
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let horizontalAmount = value.translation.width
                        if horizontalAmount < -50 {
                            if currentPage < findLargestPage(in: connectionManager.shortcutsList.flatMap(\.shortcuts))  {
                                currentPage += 1
                            }
                        } else if horizontalAmount > 50 {
                            if currentPage > 1 {
                                currentPage -= 1
                            }
                        }
                    }
            )
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
        return identifier == "iPad16,3" || identifier == "iPad16,4" // M4 13-inch
    }

    func isIPadPro11Inch() -> Bool {
        let identifier = getDeviceModelIdentifier()
        return identifier == "iPad16,1" || identifier == "iPad16,2" // M4 11-inch
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
            connectionManager.receivedInvite = false
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
                    if connectionManager.pairingStatus == .paired {
                        Button {
                            showsDisconnectAlert = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                    showsConnectionView = true
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


import Foundation
import SystemConfiguration

struct StreamView: View {
    @StateObject private var client = LiveStreamClient()
    @GestureState private var dragOffset = CGSize.zero
    @State private var dragLocation: CGPoint = .zero
    @State private var tapLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var tapPerformed = false
    @State private var scrollOffset: CGFloat = 0
    @State private var doubleTapThreshold: TimeInterval = 0.3
    @State private var lastTapTime: Date? = nil
    @State private var seenTutorial: Bool = false
    
    private let serverIP: String
    
    init(serverIP: String) {
        self.serverIP = serverIP
    }

    var body: some View {
        VStack {
            if let image = client.image {
                GeometryReader { geometry in
                    ZStack {
                        imageView(image, geometry: geometry)
                        if !seenTutorial {
                            Rectangle()
                                .fill(Color.black.opacity(0.9))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            TouchControlTutorialView {
                                seenTutorial = true
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 28/255, green: 28/255, blue: 30/255))
                                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
                            )
                            .padding()
                        }
                    }
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            seenTutorial = KeychainManager().retrieve(key: .seenTouchTutorial) ?? Keys.seenTouchTutorial.defaultValue
            client.connect(to: serverIP)
        }
        .onDisappear {
            client.disconnect()
        }
        .ignoresSafeArea()
    }
    
    func imageView(_ image: UIImage, geometry: GeometryProxy) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .background(Color.black)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let delta = value.translation
                        self.client.sendMouseClick(
                            moveUpdateType: .scroll,
                            dx: delta.width,
                            dy: delta.height
                        )
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.3)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, .some(let drag)):
                            if !isDragging {
                                isDragging = true
                                dragLocation = translatedPoint(originalSize: geometry.size, targetSize: image.size, from: drag.startLocation)
                                self.client.sendMouseClick(
                                    moveUpdateType: .selectAndDragStart,
                                    dx: dragLocation.x,
                                    dy: dragLocation.y
                                )
                            } else {
                                let translation = translatedPoint(originalSize: geometry.size, targetSize: image.size, from: drag.location)
                                self.client.sendMouseClick(
                                    moveUpdateType: .selectAndDragUpdate,
                                    dx: translation.x,
                                    dy: translation.y
                                )
                            }
                        default: break
                        }
                    }
                    .onEnded { value in
                        if case .second(true, .some(let drag)) = value {
                            let translation = translatedPoint(originalSize: geometry.size, targetSize: image.size, from: drag.location)
                            self.client.sendMouseClick(
                                moveUpdateType: .selectAndDragEnd,
                                dx: translation.x,
                                dy: translation.y
                            )
                        }
                        isDragging = false
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        if !isDragging {
                            tapPerformed = true
                            let translated = translatedPoint(originalSize: geometry.size, targetSize: image.size, from: tapLocation)
                            self.client.sendMouseClick(
                                moveUpdateType: .click,
                                dx: translated.x,
                                dy: translated.y
                            )
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        let translated = translatedPoint(originalSize: geometry.size, targetSize: image.size, from: tapLocation)
                        self.client.sendMouseClick(
                            moveUpdateType: .doubleClick,
                            dx: translated.x,
                            dy: translated.y
                        )
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        tapLocation = value.location
                    }
            )
    }

    func translatedPoint(originalSize: CGSize, targetSize: CGSize, from tapLocation: CGPoint) -> CGPoint {
        let scaleX = targetSize.width / originalSize.width
        let scaleY = targetSize.height / originalSize.height
        return CGPoint(x: tapLocation.x * scaleX, y: tapLocation.y * scaleY)
    }
}

struct TouchControlTutorialView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var currentPage = 0
    var closeAction: () -> Void

    let pages: [TutorialPage] = [
        TutorialPage(
            title: "Welcome to Touch Display",
            description: "This is a virtual macOS display, accessible on your MobiliyControl app. You can control display using a mouse or touch gestures.",
            icon: "rectangle.and.hand.point.up.left.fill"
        ),
        TutorialPage(
            title: "Single Tap",
            description: "Tap anywhere on the screen to perform a single click. This works just like a left-click with your mouse.",
            icon: "hand.tap"
        ),
        TutorialPage(
            title: "Double Tap",
            description: "Double tap quickly on a screen area to perform a double click. Use it to open files, folders, or apps.",
            icon: "hand.tap.fill"
        ),
        TutorialPage(
            title: "Long Press & Drag",
            description: "Touch and hold for about a second to begin dragging the selected item. Perfect for moving windows or icons.",
            icon: "hand.point.up.left.fill"
        ),
        TutorialPage(
            title: "Scroll with Drag",
            description: "To scroll, touch the screen once and drag with your finger. Smoothly navigate content in windows or apps.",
            icon: "hand.draw.fill"
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    TutorialPageView(page: pages[index])
                        .tag(index)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            Button(action: {
                if currentPage < pages.count - 1 {
                    currentPage += 1
                } else {
                    KeychainManager().save(key: .seenTouchTutorial, value: true)
                    closeAction()
                }
            }) {
                Text(currentPage == pages.count - 1 ? "Done" : "Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 370)
    }
}


struct TutorialPage {
    let title: String
    let description: String
    let icon: String
}

struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: page.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.top, 10)

            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }
}
