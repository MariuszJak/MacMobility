//
//  View+Ext.swift
//
//  Created by Mariusz Jakowienko on 16/03/2025.
//

import SwiftUI

public extension View {
    @ViewBuilder
    func `ifLet`<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ conditional: Bool, content: (Self) -> Content) -> some View {
         if conditional {
             content(self)
         } else {
             self
         }
     }
}

extension View {
    func outlinedText(strokeColor: Color = .black, lineWidth: CGFloat = 2) -> some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                self
                    .offset(x: CGFloat(cos(Double(i) / 16 * 2 * .pi)) * lineWidth,
                            y: CGFloat(sin(Double(i) / 16 * 2 * .pi)) * lineWidth)
                    .foregroundColor(strokeColor)
            }
            self
        }
    }
}
