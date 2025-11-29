//
//  AppHeaderView.swift
//  maistro
//

import SwiftUI

struct AppHeaderView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let title: String
    let showBackButton: Bool
    let showSettingsButton: Bool
    let onBack: (() -> Void)?
    let onSettings: (() -> Void)?

    init(
        title: String,
        showBackButton: Bool,
        showSettingsButton: Bool,
        onBack: (() -> Void)?,
        onSettings: (() -> Void)?
    ) {
        self.title = title
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
                .padding()
            } else {
                Spacer()
                    .frame(width: 36)
                    .padding()
            }

            Spacer()

            // Center - Title
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(themeManager.colors.textPrimary)

            Spacer()

            // Right side - Settings button
            if showSettingsButton {
                ThemedButton(
                    systemName: "paintbrush",
                    type: .secondary,
                    size: .small,
                    action: { onSettings?() }
                )
                .padding()
            } else {
                Spacer()
                    .frame(width: 36)
                    .padding()
            }
        }
        .background(themeManager.colors.primary.opacity(0.7))
    }
}

#Preview {
    AppHeaderView(
        title: "Rhythm Practice",
        showBackButton: true,
        showSettingsButton: true,
        onBack: {},
        onSettings: {}
    )
    .environmentObject(ThemeManager.shared)
}
