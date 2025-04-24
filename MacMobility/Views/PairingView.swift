//
//  PairingView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 24/04/2025.
//

import SwiftUI

struct PairingView: View {
    @StateObject var connectionManager: ConnectionManager
    @Binding var isPresented: Bool
    let deviceName: String
    var onConnect: () -> Void
    var onReject: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            HStack {
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                        .padding()
                }
            }
            VStack(spacing: 24) {
                Spacer()
                Text("Connect to:")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(deviceName)
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 20) {
                    Button(action: {
                        onConnect()
                    }) {
                        Text("Connect")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    Button(action: {
                        onReject()
                    }) {
                        Text("Reject")
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 78.0)
                .frame(maxWidth: 400.0)
                Spacer()
            }
        }
        .background(
            BackgroundBlurView()
                .ignoresSafeArea()
        )
    }
}
