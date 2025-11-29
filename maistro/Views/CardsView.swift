//
//  CardsView.swift
//  maistro
//

import SwiftUI

struct CardsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter
    @State private var showingThemeSheet = false

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(appCards) { card in
                    FeatureCard(
                        title: card.title,
                        description: card.description,
                        disabled: card.disabled,
                        action: {
                            viewRouter.navigate(to: card.view)
                        }
                    )
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .top) {
            AppHeaderView(
                title: "Maistro",
                showBackButton: false,
                showSettingsButton: true,
                onBack: {},
                onSettings: {
                    showingThemeSheet = true
                }
            )
        }
        .background(
            themeManager.colors.neutral
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showingThemeSheet) {
            ThemePickerSheet()
        }
    }
}

struct ThemePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(Theme.allCases) { theme in
                    Button(action: {
                        themeManager.currentTheme = theme
                    }) {
                        HStack {
                            // Theme preview colors
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(theme.colors.primary)
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(theme.colors.secondary)
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(theme.colors.neutral)
                                    .frame(width: 24, height: 24)
                            }

                            Text(theme.displayName)
                                .foregroundColor(themeManager.colors.textNeutral)
                                .padding(.leading, 8)

                            Spacer()

                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.colors.confirmation)
                            }
                        }
                    }
                    .listRowBackground(themeManager.colors.neutral)
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.colors.neutral)
            .navigationTitle("Choose Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.colors.textPrimary)
                }
            }
        }
    }
}

#Preview {
    CardsView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
