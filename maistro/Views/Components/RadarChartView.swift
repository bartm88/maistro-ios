//
//  RadarChartView.swift
//  maistro
//

import SwiftUI

struct RadarChartDataPoint: Identifiable {
    let id: String
    let label: String
    let score: Double  // 0.0 to 1.0

    init(id: String, label: String, score: Double) {
        self.id = id
        self.label = label
        self.score = score
    }
}

struct RadarChartView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let dataPoints: [RadarChartDataPoint]
    let size: CGFloat
    let labelPadding: CGFloat
    let onAxisTapped: ((RadarChartDataPoint) -> Void)?

    private var axisCount: Int {
        dataPoints.count
    }

    private var anglePerAxis: Double {
        (2 * .pi) / Double(axisCount)
    }

    private var labelRadius: CGFloat {
        radius + 20
    }

    private var radius: CGFloat {
        (size - labelPadding * 2) / 2.5
    }

    // Calculate center offset to visually center the chart based on label positions
    private var centerOffset: CGPoint {
        guard axisCount >= 3 else { return .zero }

        var minY: CGFloat = .infinity
        var maxY: CGFloat = -.infinity
        var minX: CGFloat = .infinity
        var maxX: CGFloat = -.infinity

        for i in 0..<axisCount {
            let angle = angleForAxis(i) - .pi / 2
            let x = labelRadius * cos(angle)
            let y = labelRadius * sin(angle)
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        // Calculate how much to offset to center the bounding box
        let offsetX = -(minX + maxX) / 2
        let offsetY = -(minY + maxY) / 2

        return CGPoint(x: offsetX, y: offsetY)
    }

    private var center: CGPoint {
        CGPoint(x: size / 2 + centerOffset.x, y: size / 2 + centerOffset.y)
    }

    var body: some View {
        ZStack {
            // Background web/grid
            radarGrid

            // Data polygon
            dataPolygon

            // Axis labels with tap targets
            axisLabels
        }
        .frame(width: size, height: size)
        .background(themeManager.colors.neutral)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
        )
    }

    private var radarGrid: some View {
        ZStack {
            // Concentric polygons (grid levels)
            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                gridPolygon(at: level)
            }

            // Axis lines from center to each vertex
            ForEach(0..<axisCount, id: \.self) { index in
                axisLine(at: index)
            }
        }
    }

    private func gridPolygon(at level: Double) -> some View {
        Path { path in
            guard axisCount >= 3 else { return }

            for i in 0...axisCount {
                let angle = angleForAxis(i % axisCount) - .pi / 2
                let r = radius * level
                let x = center.x + r * cos(angle)
                let y = center.y + r * sin(angle)

                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(themeManager.colors.neutralAccent.opacity(0.3), lineWidth: 1)
    }

    private func axisLine(at index: Int) -> some View {
        Path { path in
            let angle = angleForAxis(index) - .pi / 2
            let endX = center.x + radius * cos(angle)
            let endY = center.y + radius * sin(angle)

            path.move(to: center)
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(themeManager.colors.neutralAccent.opacity(0.5), lineWidth: 1)
    }

    private var dataPolygon: some View {
        ZStack {
            // Filled polygon
            Path { path in
                guard axisCount >= 3 else { return }

                for (i, dataPoint) in dataPoints.enumerated() {
                    let angle = angleForAxis(i) - .pi / 2
                    let r = radius * dataPoint.score
                    let x = center.x + r * cos(angle)
                    let y = center.y + r * sin(angle)

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
            .fill(themeManager.colors.primary.opacity(0.3))

            // Polygon stroke
            Path { path in
                guard axisCount >= 3 else { return }

                for (i, dataPoint) in dataPoints.enumerated() {
                    let angle = angleForAxis(i) - .pi / 2
                    let r = radius * dataPoint.score
                    let x = center.x + r * cos(angle)
                    let y = center.y + r * sin(angle)

                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
            .stroke(themeManager.colors.primaryAccent, lineWidth: 2)

            // Data points at vertices
            ForEach(0..<axisCount, id: \.self) { index in
                dataPointCircle(at: index)
            }
        }
    }

    private func dataPointCircle(at index: Int) -> some View {
        let dataPoint = dataPoints[index]
        let angle = angleForAxis(index) - .pi / 2
        let r = radius * dataPoint.score
        let x = center.x + r * cos(angle)
        let y = center.y + r * sin(angle)

        return Circle()
            .fill(scoreColor(for: dataPoint.score))
            .frame(width: 8, height: 8)
            .position(x: x, y: y)
    }

    private var axisLabels: some View {
        ForEach(0..<axisCount, id: \.self) { index in
            axisLabel(at: index)
        }
    }

    private func axisLabel(at index: Int) -> some View {
        let dataPoint = dataPoints[index]
        let angle = angleForAxis(index) - .pi / 2
        let x = center.x + labelRadius * cos(angle)
        let y = center.y + labelRadius * sin(angle)

        return Text(dataPoint.label)
            .font(.caption2)
            .foregroundColor(themeManager.colors.textNeutral)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .position(x: x, y: y)
            .contentShape(Rectangle().size(width: 50, height: 20))
            .onTapGesture {
                onAxisTapped?(dataPoint)
            }
    }

    private func angleForAxis(_ index: Int) -> Double {
        Double(index) * anglePerAxis
    }

    private func scoreColor(for score: Double) -> Color {
        if score >= 0.8 {
            return themeManager.colors.confirmation
        } else if score >= 0.5 {
            return themeManager.colors.primary
        } else {
            return themeManager.colors.negative
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // 3 categories (like current evaluation)
        RadarChartView(
            dataPoints: [
                RadarChartDataPoint(id: "duration", label: "Duration", score: 0.9),
                RadarChartDataPoint(id: "rhythm", label: "Rhythm", score: 0.6),
                RadarChartDataPoint(id: "pitch", label: "Pitch", score: 0.4)
            ],
            size: 200,
            labelPadding: 20,
            onAxisTapped: { point in
                print("Tapped: \(point.label)")
            }
        )

        // 5 categories
        RadarChartView(
            dataPoints: [
                RadarChartDataPoint(id: "timing", label: "Timing", score: 0.85),
                RadarChartDataPoint(id: "dynamics", label: "Dynamics", score: 0.7),
                RadarChartDataPoint(id: "articulation", label: "Articulation", score: 0.55),
                RadarChartDataPoint(id: "accuracy", label: "Accuracy", score: 0.9),
                RadarChartDataPoint(id: "tempo", label: "Tempo", score: 0.65)
            ],
            size: 250,
            labelPadding: 30,
            onAxisTapped: nil
        )

        // 6 categories
        RadarChartView(
            dataPoints: [
                RadarChartDataPoint(id: "a", label: "A", score: 0.8),
                RadarChartDataPoint(id: "b", label: "B", score: 0.6),
                RadarChartDataPoint(id: "c", label: "C", score: 0.9),
                RadarChartDataPoint(id: "d", label: "D", score: 0.4),
                RadarChartDataPoint(id: "e", label: "E", score: 0.7),
                RadarChartDataPoint(id: "f", label: "F", score: 0.5)
            ],
            size: 180,
            labelPadding: 15,
            onAxisTapped: nil
        )
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
