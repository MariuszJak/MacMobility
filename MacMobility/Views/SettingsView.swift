//
//  SettingsView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 23/04/2025.
//

import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var lockLandscape = true
    @Published var autoconnect = false
    
    init() {
        self._lockLandscape = .init(initialValue: KeychainManager().retrieve(key: .lockLandscape) ?? Keys.lockLandscape.defaultValue)
        self._autoconnect = .init(initialValue: KeychainManager().retrieve(key: .autoconnect) ?? Keys.autoconnect.defaultValue)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel = SettingsViewModel()
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                }
            }
            .padding()
            VStack(spacing: 16) {
                ScrollView {
                    Toggle("Lock to landscape", isOn: $viewModel.lockLandscape)
                        .onChange(of: viewModel.lockLandscape) { newValue in
                            KeychainManager().save(key: .lockLandscape, value: newValue)
                            OrientationManager.lock(to: newValue ? .landscape : .all)
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                    Toggle("Autoconnect to last paired device (experimental)", isOn: $viewModel.autoconnect)
                        .onChange(of: viewModel.autoconnect) { newValue in
                            KeychainManager().save(key: .autoconnect, value: newValue)
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 36.0)
            Spacer()
        }
        .background(
            BackgroundBlurView()
                .ignoresSafeArea()
        )
    }
}
