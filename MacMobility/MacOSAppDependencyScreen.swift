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
                firstPage
                secondPage
                lastPage
            }
            .tabViewStyle(.page)
        }
    }
    
    var firstPage: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Spacer()
            Image("macosapp")
            Spacer()
            Divider()
            Text("For this app to work, you need to download MacOS companion application.")
                .font(.system(size: 12.0))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding()
    }
    
    var secondPage: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Spacer()
            Image("githubpage")
                .resizable()
                .aspectRatio(contentMode: .fit)
            Spacer()
            Divider()
            Button("Copy url to github page.") {
                copyGithubPageToClipboard()
            }
            .font(.system(size: 12.0))
            .foregroundStyle(.white)
            Spacer()
        }
        .padding()
    }
    
    var lastPage: some View {
        VStack(alignment: .center, spacing: 16.0) {
            Text("Everythnig installed and ready to go?")
            Button("Close") {
                dismiss()
            }
            .font(.system(size: 12.0))
            .foregroundStyle(.white)
        }
    }
    
    func copyGithubPageToClipboard() {
        let pasteboard = UIPasteboard.general
        pasteboard.string = "https://github.com/MariuszJak/MagicTrackpad"
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
