//
//  CompactScoreView.swift
//  maistro
//

import SwiftUI

struct CompactScoreView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let scores: [Double]
    let size: CGFloat
    let onTap: (() -> Void)?

    private var aggregateScore: Double {
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var scoreColor: Color {
        if aggregateScore >= 0.8 {
            return themeManager.colors.confirmation
        } else if aggregateScore >= 0.5 {
            return themeManager.colors.primary
        } else {
            return themeManager.colors.negative
        }
    }

    private var displayPercentage: Int {
        Int(aggregateScore * 100)
    }

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(themeManager.colors.neutral)
                    .frame(width: size, height: size)

                // Progress ring
                Circle()
                    .trim(from: 0, to: aggregateScore)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                    )
                    .frame(width: size * 0.8, height: size * 0.8)
                    .rotationEffect(.degrees(-90))

                // Score text
                Text("\(displayPercentage)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.colors.textNeutral)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 20) {
        CompactScoreView(
            scores: [0.9, 0.85, 1.0],
            size: 50,
            onTap: nil
        )

        CompactScoreView(
            scores: [0.6, 0.7, 0.5],
            size: 50,
            onTap: nil
        )

        CompactScoreView(
            scores: [0.3, 0.4, 0.2],
            size: 50,
            onTap: nil
        )
    }
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager.shared)
}
