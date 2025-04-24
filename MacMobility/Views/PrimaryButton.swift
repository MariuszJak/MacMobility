//
//  PrimaryButton.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 19/04/2025.
//

import SwiftUI

struct PrimaryButton: View {
    @Environment(\.colorScheme) var colorScheme

    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(title)
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .font(.system(size: 14.0, weight: .bold))
            }
            .padding(.all, 10.0)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? colorScheme == .dark ? .white : .black : .gray))
            .shadow(radius: 2)
            .scaleEffect(isSelected ? 1.0 : 0.85)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
