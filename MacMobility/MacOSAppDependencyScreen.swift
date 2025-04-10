//
//  MacOSAppDependencyScreen.swift
//  MagicTrackpad
//
//  Created by Mariusz Jakowienko on 13/01/2024.
//

import Foundation
import SwiftUI
import Combine

enum WorkspaceControl: String, CaseIterable {
    case prev, next
}

struct MacOSAppDependencyScreen: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack {
            TabView {
                initialPage
                firstPage
                lastPage
            }
            .tabViewStyle(.page)
        }
    }
    
    var initialPage: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Spacer()
                .frame(height: 56.0)
            OrientationStack {
                Image(.logo)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .padding()
                VStack(alignment: .leading) {
                    Text("Welcome to MacMobility!")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.bottom, 6.0)
                    Text("Take control of your MacOS with MacMobility app!")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.gray)
                }
            }
        }
        .padding()
    }
    
    var firstPage: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Spacer()
                .frame(height: 56.0)
            OrientationStack {
                Image("macosapp")
                    .padding()
                VStack(alignment: .leading) {
                    Text("MacOS companion application")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.bottom, 6.0)
                    Text("For this application to work, you need to download MacOS companion application.\nIt is available on the webpage: www.coderblocks.eu/macmobility. Download it and install on your Mac, and then you can continue.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.gray)
                }
            }
        }
        .padding()
    }
    
    var lastPage: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Text("Everything installed and ready to go?")
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 2.0)
            Text("Now you are able to use MacMobility app on your Mac!")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.gray)
                .padding(.bottom, 22.0)
            PrimaryButton(title: "Start!", isSelected: true) {
                dismiss()
            }
            .frame(width: 200.0)
        }
    }
}

@propertyWrapper
final class UserDefault<T>: NSObject {
    var wrappedValue: T {
        get {
            return userDefaults.object(forKey: key) as! T
        }
        set {
            userDefaults.setValue(newValue, forKey: key)
        }
    }
    var projectedValue: AnyPublisher<T, Never> {
        return subject.eraseToAnyPublisher()
    }

    private let key: String
    private let userDefaults: UserDefaults
    private var observerContext = 0
    private let subject: CurrentValueSubject<T, Never>

    init(wrappedValue defaultValue: T, _ key: String, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
        self.subject = CurrentValueSubject(defaultValue)
        super.init()
        userDefaults.register(defaults: [key: defaultValue])
        userDefaults.addObserver(self, forKeyPath: key, options: .new, context: &observerContext)
        subject.value = wrappedValue
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?) {
        if context == &observerContext {
            subject.value = wrappedValue
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    deinit {
        userDefaults.removeObserver(self, forKeyPath: key, context: &observerContext)
    }
}

struct OrientationStack<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            Group {
                if isLandscape {
                    HStack { content() }
                } else {
                    VStack { content() }
                }
            }
        }
    }
}
