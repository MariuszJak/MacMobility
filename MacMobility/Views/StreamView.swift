//
//  StreamView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 22/05/2025.
//

import Foundation
import SystemConfiguration
import SwiftUI
import AVFoundation
import UIKit

struct VideoLayerView: UIViewRepresentable {
    @ObservedObject var liveStreamClient: LiveStreamClient
    let size: CGSize

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(liveStreamClient.videoLayer)
        liveStreamClient.videoLayer.videoGravity = .resizeAspect
        liveStreamClient.videoLayer.isHidden = false
        liveStreamClient.videoLayer.bounds = view.bounds
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        liveStreamClient.videoLayer.frame = .init(x: 0.0, y: 0.0, width: size.width, height: size.height)
        DispatchQueue.main.async {
            liveStreamClient.videoLayer.setNeedsLayout()
        }
    }
}

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
            GeometryReader { geometry in
                ZStack {
                    VideoLayerView(liveStreamClient: client, size: geometry.size)
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
                                            dragLocation = translatedPoint(originalSize: geometry.size, targetSize: .screenSize, from: drag.startLocation)
                                            self.client.sendMouseClick(
                                                moveUpdateType: .selectAndDragStart,
                                                dx: dragLocation.x,
                                                dy: dragLocation.y
                                            )
                                        } else {
                                            let translation = translatedPoint(originalSize: geometry.size, targetSize: .screenSize, from: drag.location)
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
                                        let translation = translatedPoint(originalSize: geometry.size, targetSize: .screenSize, from: drag.location)
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
                                        let translated = translatedPoint(originalSize: geometry.size, targetSize: .screenSize, from: tapLocation)
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
                                    let translated = translatedPoint(originalSize: geometry.size, targetSize: .screenSize, from: tapLocation)
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

    func translatedPoint(originalSize: CGSize, targetSize: CGSize, from tapLocation: CGPoint) -> CGPoint {
        let scaleX = targetSize.width / originalSize.width
        let scaleY = targetSize.height / originalSize.height
        return CGPoint(x: tapLocation.x * scaleX, y: tapLocation.y * scaleY)
    }
}

extension CGSize {
    static var screenSize: CGSize {
        let screen = UIScreen.main
        let size = screen.bounds.size
        let scale = screen.scale
        
        let width = Int((size.width * scale) * 0.5)
        let height = Int((size.height * scale) * 0.5)
        return .init(width: width, height: height)
    }
}
