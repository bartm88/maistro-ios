//
//  AppHeaderView.swift
//  maistro
//

import SwiftUI

struct AppHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let subtitle: String?
    let showBackButton: Bool
    let showSettingsButton: Bool
    let onBack: (() -> Void)?
    let onSettings: (() -> Void)?

    init(
        title: String = "Maistro",
        subtitle: String? = nil,
        showBackButton: Bool = false,
        showSettingsButton: Bool = true,
        onBack: (() -> Void)? = nil,
        onSettings: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showBackButton = showBackButton
        self.showSettingsButton = showSettingsButton
        self.onBack = onBack
        self.onSettings = onSettings
    }

    var body: some View {
        HStack {
            // Left side - Back button
            if showBackButton {
                ThemedButton(
                    systemName: "chevron.left",
                    type: .secondary,
                    size: .small,
                    action: { onBack?() }
                )
            } else {
                Spacer()
                    .frame(width: 36)
            }

            Spacer()

            // Center - Title and subtitle
            VStack(spacing: 4) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.textNeutral)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.colors.textPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(themeManager.colors.neutral)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
            )

            Spacer()

            // Right side - Settings button
            if showSettingsButton {
                ThemedButton(
                    systemName: "paintbrush",
                    type: .secondary,
                    size: .small,
                    action: { onSettings?() }
                )
            } else {
                Spacer()
                    .frame(width: 36)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    AppHeaderView(
        title: "Maistro",
        subtitle: "Rhythm Practice",
        showBackButton: true,
        showSettingsButton: true,
        onBack: {},
        onSettings: {}
    )
    .environmentObject(ThemeManager.shared)
}
