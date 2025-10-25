//
//  RotaryKnob.swift
//  MacMobility
//
//  Created by Mariusz Jakowienko on 12/08/2025.
//

import Foundation
import SwiftUI

struct RotaryKnob: View {
    @State private var angle: Double = 0
    @State private var startAngle: Double
    @State private var dragStartAngle: Double = 0
    private var throttler = Throttler<Int>(seconds: 0.25)
    var completion: (Int) -> Void
    let title: String
    var item: ShortcutObject
    
    init(
        item: ShortcutObject,
        title: String,
        completion: @escaping (Int) -> Void
    ) {
        self.title = title
        self.completion = completion
        self.item = item
        throttler.action = { value in
            completion(value)
        }
        
        if let value = item.color, value.contains("INITIAL") {
            let sanitizedValue = value.replacingOccurrences(of: "INITIAL:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let minInput = 0.0
            let maxInput = 100.0
            let minOutput = 0.0
            let maxOutput = 360.0
            let test = minOutput + ((Double(sanitizedValue) ?? 0.0) - minInput) * (maxOutput - minOutput) / (maxInput - minInput)
            angle = test
            startAngle = test
        } else {
            startAngle = 0.0
        }
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                .shadow(color: .black.opacity(0.05), radius: 4)

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let knobRadius = size * 0.45
                let markerOffset = knobRadius * 0.75
                let dotOffset = knobRadius * 0.9

                ZStack {
                    // Knob base
                    Circle()
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .shadow(color: .black.opacity(0.08), radius: 4)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.4))
                        )
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .position(center)

                    // Fixed top dot
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .position(x: center.x, y: center.y - dotOffset)

                    // Rotating marker
                    Circle()
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .frame(width: knobRadius * 2, height: knobRadius * 2)
                        .overlay(
                            Rectangle()
                                .fill(Color.init(hex: "FF6906"))
                                .frame(width: 6, height: markerOffset)
                                .offset(y: -markerOffset / 2)
                        )
                        .rotationEffect(.degrees(angle))
                        .position(center)

                    // Arc from top dot to marker (always visible)
                    ArcFullSweepShape(center: center,
                                      radius: dotOffset,
                                      startDeg: -90,
                                      sweepDeg: angle)
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .foregroundColor(Color.init(hex: "FF6906"))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let dragAngle = atan2(dy, dx) * 180 / .pi
                            
                            if value.startLocation == value.location {
                                startAngle = angle
                                dragStartAngle = dragAngle
                            } else {
                                var delta = dragAngle - dragStartAngle
                                if delta < -180 { delta += 360 }
                                if delta > 180 { delta -= 360 }
                                angle = (startAngle + delta)
                                if angle < 0 { angle += 360 }
                                if angle > 360 { angle.formTruncatingRemainder(dividingBy: 360) }
                                throttler.send(Int(mapKnobValue(angle)))
                            }
                        }
                )
            }
//            .frame(width: 200, height: 200)
        }
    }
    
    func mapKnobValue(_ angle: Double) -> Double {
        let minInput = 0.0
        let maxInput = 360.0
        let minOutput = 0.0
        let maxOutput = 100.0
        return minOutput + (angle - minInput) * (maxOutput - minOutput) / (maxInput - minInput)
    }
}

// Shape that always sweeps forward from startDeg to startDeg + sweepDeg
struct ArcFullSweepShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let startDeg: Double
    let sweepDeg: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let endDeg = startDeg + sweepDeg
        p.addArc(center: center,
                 radius: radius,
                 startAngle: Angle(degrees: startDeg),
                 endAngle: Angle(degrees: endDeg),
                 clockwise: false)
        return p
    }
}
