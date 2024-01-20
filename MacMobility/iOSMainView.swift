//
//  iOSMainView.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 22/07/2023.
//

import SwiftUI

struct Preferences {
    enum Key {
        static let didSeenDependencyScreens = "didSeenDependencyScreens"
    }
}

struct AppListData: Identifiable {
    var id: String { UUID().uuidString }
    var apps: [RunningAppData]
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
            appGridView
            workspaceControls
            disconnectButtonView
//            touchpadView
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
        .animation(.easeInOut, value: $connectionManager.pairingStatus.wrappedValue)
        .padding()
    }
    
    func handlePairingStatus(with pairingStatus: PairingStatus) {
        switch pairingStatus {
        case .paired:
            connectionManager.stopAdvertising()
            connectionManager.stopBrowsing()
            connectionManager.getAppsList()
        case .notPaired:
            connectionManager.appList.removeAll()
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
    
    @ViewBuilder
    private var touchpadView: some View {
        if connectionManager.pairingStatus == .paired {
            ZStack {
                TapView { _, _, _ in }
                .gesture(DragGesture()
                    .onChanged { gesture in
                        connectionManager.send(position: .init(width: gesture.velocity.width / 25,
                                                               height: gesture.velocity.height / 25))
                    }
                    .onEnded { _ in }
                )
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

class NFingerGestureRecognizer: UIGestureRecognizer {

    var tappedCallback: (Set<UITouch>, [CGPoint?], CGFloat?) -> Void

    var touchViews = [UITouch:CGPoint]()
    
    var previousLocation: CGPoint?
    
    var startTime: TimeInterval?

    init(target: Any?, tappedCallback: @escaping (Set<UITouch>, [CGPoint?], CGFloat?) -> ()) {
        self.tappedCallback = tappedCallback
        super.init(target: target, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            let location = touch.location(in: touch.view)
            touchViews[touch] = location
        }
        startTime = CACurrentMediaTime()
        previousLocation = touches.first?.location(in: touches.first?.view)
        tappedCallback(touches, touches.map { $0.location(in: $0.view) }, nil)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            let newLocation = touch.location(in: touch.view)
            // let oldLocation = touchViews[touch]!
            // print("Move: (\(oldLocation.x)/\(oldLocation.y)) -> (\(newLocation.x)/\(newLocation.y))")
            touchViews[touch] = newLocation
        }
        let currentTime = CACurrentMediaTime()
        let newLocation = touches.first?.location(in: touches.first?.view)
        let velocity = calculateVelocity(startPoint: previousLocation,
                                         endPoint: newLocation,
                                         time: currentTime - (startTime ?? 0.0))
        tappedCallback(touches, touches.map { $0.location(in: $0.view) }, velocity)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            // let oldLocation = touchViews[touch]!
            // print("End: (\(oldLocation.x)/\(oldLocation.y))")
            touchViews.removeValue(forKey: touch)
        }
        previousLocation = nil
        startTime = nil
        tappedCallback(touches, [], nil)
    }
    
    func calculateVelocity(startPoint: CGPoint?, endPoint: CGPoint?, time: TimeInterval) -> CGFloat? {
        guard let startPoint, let endPoint else { return nil }
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y

        let velocityX = deltaX / CGFloat(time)
        let velocityY = deltaY / CGFloat(time)
        
        let magnitude = sqrt(velocityX * velocityX + velocityY * velocityY)
        print(time)
        return magnitude
    }
}

struct TapView: UIViewRepresentable {
    var tappedCallback: (Set<UITouch>, [CGPoint?], CGFloat?) -> Void

    func makeUIView(context: UIViewRepresentableContext<TapView>) -> TapView.UIViewType {
        let v = UIView(frame: .zero)
        let gesture = NFingerGestureRecognizer(target: context.coordinator,
                                               tappedCallback: tappedCallback)
        v.addGestureRecognizer(gesture)
        return v
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<TapView>) {}
}

extension View {
   @ViewBuilder
   func `if`<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> some View {
        if conditional {
            content(self)
        } else {
            self
        }
    }
}
