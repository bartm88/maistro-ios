//
//  ContentView.swift
//  maistro
//

import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var viewRouter = ViewRouter()

    var body: some View {
        ZStack {
            // Background color
            themeManager.colors.neutral
                .ignoresSafeArea()

            // View Router
            switch viewRouter.currentView {
            case .landing:
                LandingView()
                    .transition(.opacity)

            case .cards:
                CardsView()
                    .transition(.move(edge: .trailing))

            case .rhythm:
                RhythmPracticeView()
                    .transition(.move(edge: .trailing))

            case .themeTester:
                ThemeTesterView()
                    .transition(.move(edge: .trailing))

            case .sandbox:
                SandboxView()
                    .transition(.move(edge: .trailing))

            case .tuner:
                TunerView()
                    .transition(.move(edge: .trailing))

            case .pitch, .song, .sightread, .improvisation:
                // Placeholder for future views
                ComingSoonView(viewName: viewRouter.currentView.rawValue.capitalized)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewRouter.currentView)
        .environmentObject(themeManager)
        .environmentObject(viewRouter)
    }
}

struct ComingSoonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter

    let viewName: String

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundColor(themeManager.colors.primaryAccent)

                Text("Coming Soon")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.textNeutral)

                Text("This feature is under development")
                    .font(.body)
                    .foregroundColor(themeManager.colors.textNeutral.opacity(0.7))
            }

            Spacer()
        }
        .safeAreaInset(edge: .top) {
            AppHeaderView(
                title: viewName,
                showBackButton: true,
                showSettingsButton: false,
                onBack: {
                    viewRouter.goBack()
                },
                onSettings: {}
            )
        }
        .background(
            themeManager.colors.neutral
                .ignoresSafeArea()
        )
    }
}

#Preview {
    ContentView()
}
