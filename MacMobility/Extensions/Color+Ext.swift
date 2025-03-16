//
//  Color+Ext.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 16/03/2025.
//

import UIKit
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static var randomPastel: Color {
        let hue = Double.random(in: 0...1)
        let saturation = Double.random(in: 0.4...0.6)
        let brightness = Double.random(in: 0.8...1.0)

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    static var randomDarkPastel: Color {
        let hue = Double.random(in: 0...1)
        let saturation = Double.random(in: 0.6...0.8)
        let brightness = Double.random(in: 0.15...0.3)

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    func toHex(alpha: Bool = false) -> String? {
        let uiColor = UIColor(self)
        return uiColor.toHex(alpha: alpha)
    }
}
