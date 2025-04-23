//
//  AppDependencyScreen.swift
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

struct AppDependencyScreen: View {
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
                    Text("Welcome to MobilityControl!")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.bottom, 6.0)
                    Text("Take control with MobilityControl app!")
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
                Image("externalApp")
                    .padding()
                VStack(alignment: .leading) {
                    Text("Companion application")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.bottom, 6.0)
                    Text("Download companion application that extends capabilities of this app!\nIt is available on the webpage: www.coderblocks.eu/mobility. Download it and install on your laptop, and then you can continue.")
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
            Text("Now you are able to use MobilityControl app on your laptop!")
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

public enum Keys: String, CaseIterable {
    case lockLandscape
}

public protocol KeychainManagerRepresentable {
    func save<T: Codable>(key: Keys, value: T) -> Bool
    func retrieve<T: Codable>(key: Keys) -> T?
    func delete(key: Keys) -> Bool
    func clear() -> Bool
}

public class KeychainManager: KeychainManagerRepresentable {
    public init() {}
    
    @discardableResult
    public func save<T: Codable>(key: Keys, value: T) -> Bool {
        let encoder = JSONEncoder()
        do {
            let valueData = try encoder.encode(value)
            
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key.rawValue,
                kSecValueData as String: valueData
            ]
            
            SecItemDelete(query as CFDictionary)
            
            let status = SecItemAdd(query as CFDictionary, nil)
            return status == errSecSuccess
        } catch {
            print("Failed to encode object: \(error)")
            return false
        }
    }
    
    public func retrieve<T: Codable>(key: Keys) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            let decoder = JSONDecoder()
            do {
                let object = try decoder.decode(T.self, from: data)
                return object
            } catch {
                print("Failed to decode object: \(error)")
                return nil
            }
        }
        return nil
    }
    
    public func delete(key: Keys) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    public func clear() -> Bool {
        for key in Keys.allCases {
            _ = delete(key: key)
        }
        return true
    }
}
