//
//  Optional+Ext.swift
//
//  Created by Mariusz Jakowienko on 16/03/2025.
//

import Foundation

public extension Optional {
    @discardableResult
    func `let`<T>(_ closure: (Wrapped) -> T) -> T? {
        if case .some(let wrapped) = self {
            return closure(wrapped)
        } else {
            return nil
        }
    }
}
