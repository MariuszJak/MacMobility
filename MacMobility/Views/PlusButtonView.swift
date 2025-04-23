//
//  PlusButtonView.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 22/04/2025.
//

import SwiftUI

struct PlusButtonView: View {
    var itemSize: CGSize
    
    var body: some View {
        let backgroundColor = Color(.sRGB, red: 0.1, green: 0.1, blue: 0.1, opacity: 1)
        let accentColor = Color(.sRGB, red: 0.3, green: 0.3, blue: 0.3, opacity: 1)

        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
        }
        .frame(width: itemSize.width, height: itemSize.height)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
    }
}
