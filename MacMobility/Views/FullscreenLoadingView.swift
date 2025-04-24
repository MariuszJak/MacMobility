//
//  FullscreenLoadingView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 24/04/2025.
//

import SwiftUI

struct FullscreenLoadingView: View {
    @Binding var isAnimating: Bool
    
    var body: some View {
        ZStack {
            VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                .edgesIgnoringSafeArea(.all)
            
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 100)
                .overlay(
                    SpinnerCircle(isAnimating: $isAnimating)
                        .frame(width: 40, height: 40)
                )
                .shadow(radius: 10)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct SpinnerCircle: View {
    @Binding var isAnimating: Bool
    @State private var rotation: Double = 0.0

    let lineWidth: CGFloat = 4
    let circleSize: CGFloat = 40

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1.0)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(rotation))
            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
            .onAppear {
                rotation = 360
            }
    }
}

// For blur view (since SwiftUI doesn't have full control)
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
