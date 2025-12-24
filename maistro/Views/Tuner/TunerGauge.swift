//
//  TunerGauge.swift
//  maistro
//
//  Speedometer-style gauge for displaying pitch deviation
//  Horizontal orientation: arc on top (0° to 180°), pivot at bottom center, green zone at top

import SwiftUI

struct TunerGauge: View {
    @EnvironmentObject var themeManager: ThemeManager
    let centsDeviation: Double
    let isActive: Bool
    let size: CGFloat

    private let maxCents: Double = 50.0
    private let arcLineWidth: CGFloat = 20

    private var clampedDeviation: Double {
        max(-maxCents, min(maxCents, centsDeviation))
    }

    private var needleAngle: Double {
        // Map -50 to +50 cents to angles
        // 0 cents = pointing up (270°), -50 = left (180°), +50 = right (360°/0°)
        270.0 + (clampedDeviation / maxCents) * 90.0
    }

    private var inTuneThreshold: Double { 5.0 }

    private var isInTune: Bool {
        isActive && abs(centsDeviation) < inTuneThreshold
    }

    private var arcRadius: CGFloat {
        size / 2 - arcLineWidth / 2
    }

    private var needleLength: CGFloat {
        arcRadius - 30
    }

    // Frame dimensions - horizontal semicircle (top half of circle)
    private var frameWidth: CGFloat {
        size
    }

    private var frameHeight: CGFloat {
        size / 2 + arcLineWidth / 2
    }

    // Pivot point - bottom center
    private var pivotX: CGFloat {
        frameWidth / 2
    }

    private var pivotY: CGFloat {
        frameHeight
    }

    var body: some View {
        Canvas { context, canvasSize in
            let pivot = CGPoint(x: pivotX, y: pivotY)

            // Draw arcs - horizontal orientation (top semicircle)
            // Flat zone at left (180°), sharp zone at right (360°), in-tune at top (270°)
            drawArc(context: context, pivot: pivot, startDeg: 180, endDeg: 360,
                   color: themeManager.colors.neutralAccent.opacity(0.3))
            drawArc(context: context, pivot: pivot, startDeg: 180, endDeg: 240,
                   color: themeManager.colors.negative.opacity(0.6))
            drawArc(context: context, pivot: pivot, startDeg: 300, endDeg: 360,
                   color: themeManager.colors.negative.opacity(0.6))
            drawArc(context: context, pivot: pivot, startDeg: 260, endDeg: 280,
                   color: themeManager.colors.confirmation.opacity(0.8))

            // Draw tick marks
            for tick in [-50, -25, 0, 25, 50] {
                // Map tick to angle: -50 -> 180° (left), 0 -> 270° (up), +50 -> 360° (right)
                let tickAngle = 270.0 + Double(tick) / 50.0 * 90.0
                let isCenter = tick == 0
                drawTickMark(context: context, pivot: pivot, angleDeg: tickAngle,
                            radius: arcRadius - 15, length: isCenter ? 15 : 10,
                            color: isCenter ? themeManager.colors.confirmation : themeManager.colors.textSecondary,
                            width: isCenter ? 3 : 2)
            }

            // Draw needle
            let needleColor = isActive ?
                (isInTune ? themeManager.colors.confirmation : themeManager.colors.primaryAccent) :
                themeManager.colors.neutralAccent.opacity(0.5)
            drawNeedle(context: context, pivot: pivot, angleDeg: needleAngle,
                      length: needleLength, color: needleColor)

            // Draw center dot
            let dotColor = isActive ?
                (isInTune ? themeManager.colors.confirmation : themeManager.colors.primaryAccent) :
                themeManager.colors.neutralAccent
            let dotRect = CGRect(x: pivot.x - 10, y: pivot.y - 10, width: 20, height: 20)
            context.fill(Circle().path(in: dotRect), with: .color(dotColor))
        }
        .frame(width: frameWidth, height: frameHeight)
        .overlay {
            // Flat label at left, Sharp label at right
            HStack {
                Text("♭")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.textSecondary)
                Spacer()
                Text("♯")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            .padding(.horizontal, 7)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 5)
        }
        .animation(.easeOut(duration: 0.1), value: needleAngle)
    }

    private func drawArc(context: GraphicsContext, pivot: CGPoint, startDeg: Double, endDeg: Double, color: Color) {
        var path = Path()
        path.addArc(
            center: pivot,
            radius: arcRadius,
            startAngle: .degrees(startDeg),
            endAngle: .degrees(endDeg),
            clockwise: false
        )
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round))
    }

    private func drawTickMark(context: GraphicsContext, pivot: CGPoint, angleDeg: Double, radius: CGFloat, length: CGFloat, color: Color, width: CGFloat) {
        let angleRad = CGFloat(angleDeg * .pi / 180)
        let innerRadius = radius - length / 2
        let outerRadius = radius + length / 2

        let start = CGPoint(
            x: pivot.x + cos(angleRad) * innerRadius,
            y: pivot.y + sin(angleRad) * innerRadius
        )
        let end = CGPoint(
            x: pivot.x + cos(angleRad) * outerRadius,
            y: pivot.y + sin(angleRad) * outerRadius
        )

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func drawNeedle(context: GraphicsContext, pivot: CGPoint, angleDeg: Double, length: CGFloat, color: Color) {
        let angleRad = CGFloat(angleDeg * .pi / 180)
        let tipRadius = length
        let baseWidth: CGFloat = 12

        let tip = CGPoint(
            x: pivot.x + cos(angleRad) * tipRadius,
            y: pivot.y + sin(angleRad) * tipRadius
        )

        // Base points perpendicular to needle direction
        let perpAngle = angleRad + .pi / 2
        let baseLeft = CGPoint(
            x: pivot.x + cos(perpAngle) * baseWidth / 2,
            y: pivot.y + sin(perpAngle) * baseWidth / 2
        )
        let baseRight = CGPoint(
            x: pivot.x - cos(perpAngle) * baseWidth / 2,
            y: pivot.y - sin(perpAngle) * baseWidth / 2
        )

        var path = Path()
        path.move(to: tip)
        path.addLine(to: baseLeft)
        path.addLine(to: baseRight)
        path.closeSubpath()

        context.fill(path, with: .color(color))
    }
}

#Preview("In Tune") {
    TunerGauge(
        centsDeviation: 0,
        isActive: true,
        size: 300
    )
    .padding()
    .background(ThemeManager.shared.colors.neutral)
    .environmentObject(ThemeManager.shared)
}

#Preview("Sharp") {
    TunerGauge(
        centsDeviation: 25,
        isActive: true,
        size: 300
    )
    .padding()
    .background(ThemeManager.shared.colors.neutral)
    .environmentObject(ThemeManager.shared)
}

#Preview("Flat") {
    TunerGauge(
        centsDeviation: -35,
        isActive: true,
        size: 300
    )
    .padding()
    .background(ThemeManager.shared.colors.neutral)
    .environmentObject(ThemeManager.shared)
}

#Preview("Inactive") {
    TunerGauge(
        centsDeviation: 0,
        isActive: false,
        size: 300
    )
    .padding()
    .background(ThemeManager.shared.colors.neutral)
    .environmentObject(ThemeManager.shared)
}
