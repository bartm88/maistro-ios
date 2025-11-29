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

#Preview {
    CardsView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
