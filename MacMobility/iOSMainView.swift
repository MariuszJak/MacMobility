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
    @UserDefault(Preferences.Key.didSeenDependencyScreens) var didSeenDependencyScreens = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @State var currentPage: Int = 1
    @StateObject var connectionManager = ConnectionManager()
    @StateObject private var orientationObserver = OrientationObserver()
    @State var startPos: CGPoint = .zero
    @State var isSwipping = true
    @State var showQRScaner = false
    @State var showDependencyScreen = false
    @State private var trigger = false
    @State private var showsWorkspaces = false
    @State private var showsDisconnectAlert = false

    var spacing: CGFloat = 12.0
    var regularFontSize: CGFloat {
        isIPad ? 24 : 12
    }
    var isIPad: Bool {
        UIDevice.current.localizedModel.contains("iPad")
    }
    var itemsSize: CGFloat {
        isIPad ? (orientationObserver.orientation.isLandscape ? 140 : (isIPadPro13Inch() ? 110 : 90)) : 80
    }
    var itemsSpacing: CGFloat {
        isIPad ? 21 : 6
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
            }
        }
        .alert("Test", isPresented: $connectionManager.receivedAlert) {
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
            AppDependencyScreen()
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
                    .frame(width: orientationObserver.orientation.isLandscape ? 650.0 : 300)
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: itemsSize), alignment: .leading)],
                  spacing: itemsSpacing) {
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
                                            .foregroundStyle(Color.white)
                                            .multilineTextAlignment(.center)
                                            .padding(.all, 3)
                                            .stroke(color: .black)
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
                                            .foregroundStyle(Color.white)
                                            .multilineTextAlignment(.center)
                                            .padding(.all, 3)
                                            .stroke(color: .black)
                                    }
                                }
                            }
                            .hoverEffect(.highlight)
                        }
                    case .controler:
                        if test.id == "horizontal-scroll" {
                            BrightnessVolumeContainerView { value in
                                var additions = test.additions ?? [:]
                                additions["value"] = value
                                connectionManager.send(shortcut: ShortcutObject.copy(from: test, additions: additions))
                            }
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
                                            .foregroundStyle(Color.white)
                                            .multilineTextAlignment(.center)
                                            .padding(.all, 3)
                                            .stroke(color: .black)
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
                                            .foregroundStyle(Color.white)
                                            .multilineTextAlignment(.center)
                                            .stroke(color: .black)
                                    }
                                }
                            }
                            .hoverEffect(.highlight)
                        }
                    }
                } else {
                    if let one = shortcuts.first(where: { $0.index == index - 1 }), one.type == .controler {
                        VStack {
                        }
                        .frame(width: itemsSize, height: itemsSize)
                        .disabled(true)
                    } else if let two = shortcuts.first(where: { $0.index == index - 2 }), two.type == .controler {
                        VStack {
                        }
                        .frame(width: itemsSize, height: itemsSize)
                        .disabled(true)
                    }  else {
                        VStack {
                        }
                        .frame(width: itemsSize, height: itemsSize)
                        .background(
                            RoundedRectangle(cornerRadius: 20.0)
                                .fill(.gray.opacity(0.2))
                        )
                    }
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
                if connectionManager.pairingStatus == .paired {
                    Button {
                        showsDisconnectAlert = true
                    } label: {
                        Image(.exit)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(Color.gray)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .padding(.bottom, 28)
        .padding(.horizontal, 48)
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
                VStack {
                    Image("ios-qr-scanner")
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .frame(width: 80, height: 80.0)
                    Text("Tap to scan QR code")
                        .font(.system(size: 16.0))
                }
                .onTapGesture {
                    showQRScaner = true
                }
                Spacer()
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

struct BrightnessVolumeContainerView: View {
    var completion: (String) -> Void
    
    init(completion: @escaping (String) -> Void) {
        self.completion = completion
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .shadow(color: .white.opacity(0.05), radius: 4, x: 0, y: -2)

            BrightnessVolumeBarView(completion: completion)
        }
        .frame(width: 265, height: 80)
    }
}

struct BrightnessVolumeBarView: View {
    @State private var progress: Double = 0.5 // Initial value
    
    var completion: (String) -> Void
    
    init(completion: @escaping (String) -> Void) {
        self.completion = completion
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background bar
            RoundedRectangle(cornerRadius: 20)
                .frame(height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray)
                )
                .shadow(radius: 6)

            // Progress bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .frame(width: geometry.size.width * progress)
                    Spacer(minLength: 0)
                }
                .frame(height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                            progress = newProgress
                            handleValueChange(progress)
                        }
                )
            }
            .frame(height: 30)
        }
        .frame(width: 200, height: 30)
    }
    
    @State private var previousRange: Int?

    func handleValueChange(_ newValue: Double) {
        guard newValue >= 0.0, newValue <= 1.0 else { return }

        let currentRange = Int(newValue * 10)

        if let previous = previousRange, currentRange != previous {
            if currentRange < previous {
                completion("down")
            } else {
                completion("up")
            }
        }
        previousRange = currentRange
    }
}
