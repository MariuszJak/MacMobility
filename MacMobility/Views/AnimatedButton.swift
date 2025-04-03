//
//  AnimatedButton.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 23/03/2025.
//

import SwiftUI

struct AnimatedButton<Label: View>: View {
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var isTapped = false
    let action: () -> Void
    let label: Label
    var isIPad: Bool {
        UIDevice.current.localizedModel.contains("iPad")
    }
    var size: CGFloat {
        isIPad ? 80 : 40
    }
    
    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }
    
    var body: some View {
        ZStack {
            Button(action: {
                startLoading()
            }) {
                label
            }
            .disabled(isLoading) // Disable button while loading
            
            if isLoading || showSuccess {
                // Overlay with animation
                Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
                
                VStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(isIPad ? 2 : 1)
                            .padding(50)
                            .frame(width: size, height: size)
                            .background(Circle().fill(Color.white).shadow(radius: 10))
                            .transition(.opacity) // Transition for fade out
                    }
                    
                    if showSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                            .foregroundColor(.green)
                            .transition(.scale)
                    }
                }
                .zIndex(1)
            }
        }
    }
    
    private func startLoading() {
        withAnimation {
            isLoading = true
        }
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                isLoading = false
                showSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showSuccess = false
                }
            }
        }
    }
}
