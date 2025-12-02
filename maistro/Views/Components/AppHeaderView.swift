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
    let showAudioInputButton: Bool
    let onBack: (() -> Void)?
    let onSettings: (() -> Void)?
    let onAudioInput: (() -> Void)?

    init(
        title: String,
        showBackButton: Bool,
        showSettingsButton: Bool,
        showAudioInputButton: Bool,
        onBack: (() -> Void)?,
        onSettings: (() -> Void)?,
        onAudioInput: (() -> Void)?
    ) {
        self.title = title
        self.showBackButton = showBackButton
        self.showSettingsButton = showSettingsButton
        self.showAudioInputButton = showAudioInputButton
        self.onBack = onBack
        self.onSettings = onSettings
        self.onAudioInput = onAudioInput
    }

    /// Convenience initializer without audio input button (backwards compatible)
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
        self.showAudioInputButton = false
        self.onBack = onBack
        self.onSettings = onSettings
        self.onAudioInput = nil
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

            // Right side - Action buttons
            HStack(spacing: 8) {
                if showAudioInputButton {
                    ThemedButton(
                        systemName: "mic.fill",
                        type: .secondary,
                        size: .small,
                        action: { onAudioInput?() }
                    )
                }

                if showSettingsButton {
                    ThemedButton(
                        systemName: "paintbrush",
                        type: .secondary,
                        size: .small,
                        action: { onSettings?() }
                    )
                }
            }
            .padding()
            .frame(minWidth: 36)
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
