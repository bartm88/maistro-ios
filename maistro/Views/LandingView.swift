//
//  LandingView.swift
//  maistro
//

import SwiftUI

struct LandingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeManager.colors.primary,
                        themeManager.colors.secondary
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Musical note decorations
                VStack {
                    HStack {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(themeManager.colors.primaryAccent.opacity(0.3))
                            .rotationEffect(.degrees(-15))
                        Spacer()
                        Image(systemName: "music.note.list")
                            .font(.system(size: 50))
                            .foregroundColor(themeManager.colors.secondaryAccent.opacity(0.3))
                            .rotationEffect(.degrees(10))
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 60)

                    Spacer()

                    HStack {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 45))
                            .foregroundColor(themeManager.colors.primaryAccent.opacity(0.3))
                            .rotationEffect(.degrees(15))
                        Spacer()
                        Image(systemName: "music.note")
                            .font(.system(size: 35))
                            .foregroundColor(themeManager.colors.secondaryAccent.opacity(0.3))
                            .rotationEffect(.degrees(-20))
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 80)
                }

                // Main content
                VStack(spacing: 20) {
                    Spacer()

                    // App title
                    Text("Maistro")
                        .font(.system(size: 56, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.colors.textPrimary)
                        .shadow(color: themeManager.colors.primaryAccent.opacity(0.5), radius: 10, x: 0, y: 5)

                    Text("Master Your Musical Journey")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.textSecondary)

                    Spacer()

                    // Tap to continue
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 30))
                            .foregroundColor(themeManager.colors.textPrimary.opacity(0.7))

                        Text("Tap anywhere to continue")
                            .font(.caption)
                            .foregroundColor(themeManager.colors.textPrimary.opacity(0.7))
                    }
                    .padding(.bottom, 60)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewRouter.navigate(to: .cards)
                }
            }
        }
    }
}

#Preview {
    LandingView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
