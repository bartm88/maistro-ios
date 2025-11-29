//
//  EvaluationChartView.swift
//  maistro
//

import SwiftUI

struct EvaluationChartView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let durationScore: Double
    let rhythmScore: Double
    let pitchScore: Double
    let width: CGFloat
    let height: CGFloat

    private var barHeight: CGFloat {
        height * 0.85
    }

    private var barWidth: CGFloat {
        width * 0.15
    }

    private var barSpacing: CGFloat {
        width * 0.08
    }

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: barSpacing) {
                ScoreBar(label: "Duration", score: durationScore, barWidth: barWidth, barHeight: barHeight)
                ScoreBar(label: "Rhythm", score: rhythmScore, barWidth: barWidth, barHeight: barHeight)
                ScoreBar(label: "Pitch", score: pitchScore, barWidth: barWidth, barHeight: barHeight)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(width: width, height: height)
        .background(themeManager.colors.neutral)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
        )
    }
}

struct ScoreBar: View {
    @EnvironmentObject var themeManager: ThemeManager

    let label: String
    let score: Double
    var barWidth: CGFloat
    var barHeight: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(themeManager.colors.neutral.opacity(0.5))
                    .frame(width: barWidth, height: barHeight)

                Rectangle()
                    .fill(scoreColor)
                    .frame(width: barWidth, height: CGFloat(score) * barHeight)
            }
            .cornerRadius(4)

            Text(label)
                .font(.caption2)
                .foregroundColor(themeManager.colors.textNeutral)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    var scoreColor: Color {
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
        EvaluationChartView(
            durationScore: 1,
            rhythmScore: 0.6,
            pitchScore: 0.3,
            width: 200,
            height: 300
        )

        EvaluationChartView(
            durationScore: 1,
            rhythmScore: 0.6,
            pitchScore: 0.3,
            width: 90,
            height: 90
        )
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
