//
//  ThemeTesterView.swift
//  maistro
//

import SwiftUI

struct ThemeTesterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter

    var body: some View {
        ZStack {
            themeManager.colors.neutral
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                AppHeaderView(
                    title: "Maistro",
                    subtitle: "Theme Tester",
                    showBackButton: true,
                    showSettingsButton: false,
                    onBack: {
                        viewRouter.goBack()
                    }
                )

                ScrollView {
                    VStack(spacing: 24) {
                        // Current theme info
                        Text("Current Theme: \(themeManager.currentTheme.displayName)")
                            .font(.headline)
                            .foregroundColor(themeManager.colors.textNeutral)
                            .padding()

                        // Theme selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Theme.allCases) { theme in
                                    ThemePreviewButton(
                                        theme: theme,
                                        isSelected: themeManager.currentTheme == theme
                                    ) {
                                        themeManager.currentTheme = theme
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                            .background(themeManager.colors.neutralAccent)
                            .padding(.horizontal)

                        // Color swatches
                        VStack(alignment: .leading, spacing: 16) {
                            ColorSwatchRow(title: "Primary", colors: [
                                ("primary", themeManager.colors.primary),
                                ("textPrimary", themeManager.colors.textPrimary),
                                ("primaryHover", themeManager.colors.primaryHover),
                                ("primaryAccent", themeManager.colors.primaryAccent)
                            ])

                            ColorSwatchRow(title: "Secondary", colors: [
                                ("secondary", themeManager.colors.secondary),
                                ("textSecondary", themeManager.colors.textSecondary),
                                ("secondaryHover", themeManager.colors.secondaryHover),
                                ("secondaryAccent", themeManager.colors.secondaryAccent)
                            ])

                            ColorSwatchRow(title: "Neutral", colors: [
                                ("neutral", themeManager.colors.neutral),
                                ("textNeutral", themeManager.colors.textNeutral),
                                ("neutralHover", themeManager.colors.neutralHover),
                                ("neutralAccent", themeManager.colors.neutralAccent)
                            ])

                            ColorSwatchRow(title: "Confirmation", colors: [
                                ("confirmation", themeManager.colors.confirmation),
                                ("textConfirmation", themeManager.colors.textConfirmation),
                                ("confirmationHover", themeManager.colors.confirmationHover),
                                ("confirmationAccent", themeManager.colors.confirmationAccent)
                            ])

                            ColorSwatchRow(title: "Negative", colors: [
                                ("negative", themeManager.colors.negative),
                                ("textNegative", themeManager.colors.textNegative),
                                ("negativeHover", themeManager.colors.negativeHover),
                                ("negativeAccent", themeManager.colors.negativeAccent)
                            ])
                        }
                        .padding(.horizontal)

                        Divider()
                            .background(themeManager.colors.neutralAccent)
                            .padding(.horizontal)

                        // Button examples
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Buttons")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.textNeutral)

                            HStack(spacing: 12) {
                                ThemedButton("Primary", type: .primary, action: {})
                                ThemedButton("Secondary", type: .secondary, action: {})
                            }

                            HStack(spacing: 12) {
                                ThemedButton("Neutral", type: .neutral, action: {})
                                ThemedButton("Confirm", type: .confirmation, action: {})
                                ThemedButton("Negative", type: .negative, action: {})
                            }

                            HStack(spacing: 12) {
                                ThemedButton(systemName: "plus", type: .primary, action: {})
                                ThemedButton(systemName: "minus", type: .secondary, action: {})
                                ThemedButton(systemName: "xmark", type: .negative, action: {})
                                ThemedButton(systemName: "checkmark", type: .confirmation, action: {})
                            }
                        }
                        .padding(.horizontal)

                        Divider()
                            .background(themeManager.colors.neutralAccent)
                            .padding(.horizontal)

                        // Card examples
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cards")
                                .font(.headline)
                                .foregroundColor(themeManager.colors.textNeutral)

                            FeatureCard(
                                title: "Enabled Card",
                                description: "This is an example of an enabled feature card",
                                disabled: false,
                                action: {}
                            )

                            FeatureCard(
                                title: "Disabled Card",
                                description: "This is an example of a disabled feature card",
                                disabled: true,
                                action: {}
                            )
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
            }
        }
    }
}

struct ThemePreviewButton: View {
    @EnvironmentObject var themeManager: ThemeManager

    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Circle()
                        .fill(theme.colors.primary)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(theme.colors.secondary)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(theme.colors.neutral)
                        .frame(width: 20, height: 20)
                }

                Text(theme.displayName)
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textNeutral)
            }
            .padding(8)
            .background(isSelected ? themeManager.colors.primaryHover : themeManager.colors.neutral)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? themeManager.colors.primaryAccent : themeManager.colors.neutralAccent,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct ColorSwatchRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let colors: [(String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.colors.textNeutral)

            HStack(spacing: 8) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .frame(width: 60, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )

                        Text(name)
                            .font(.system(size: 8))
                            .foregroundColor(themeManager.colors.textNeutral)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
        }
    }
}

#Preview {
    ThemeTesterView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
