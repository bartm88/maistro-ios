//
//  FeatureCard.swift
//  maistro
//

import SwiftUI

struct FeatureCard: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let description: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !disabled {
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(disabled ? Color.gray : themeManager.colors.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(disabled ? Color.gray.opacity(0.7) : themeManager.colors.textPrimary.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(disabled ? Color.gray.opacity(0.1) : themeManager.colors.primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        disabled ? Color.gray.opacity(0.3) : themeManager.colors.primaryAccent,
                        lineWidth: 1
                    )
            )
            .opacity(disabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    VStack {
        FeatureCard(
            title: "Rhythm Practice",
            description: "Practice rhythm patterns and timing",
            disabled: false,
            action: {}
        )

        FeatureCard(
            title: "Pitch Training",
            description: "Improve your pitch recognition",
            disabled: true,
            action: {}
        )
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
