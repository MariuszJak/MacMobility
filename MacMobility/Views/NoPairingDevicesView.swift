//
//  NoPairingDevicesView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 24/04/2025.
//

import SwiftUI

struct NoPairingDevicesView: View {
    @Binding var isPresented: Bool
    
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
                Text("No Devices Detected")
                    .font(.largeTitle)
                    .bold()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("There are no devices available to connect to.\n\nPlease ensure your Bluetooth is turned on and try again.")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    
                HStack(spacing: 20) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Dismiss")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
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
