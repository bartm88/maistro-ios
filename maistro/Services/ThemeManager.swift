//
//  ThemeManager.swift
//  maistro
//

import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: Theme {
        didSet {
            saveTheme()
        }
    }

    private let themeKey = "selectedTheme"

    private init() {
        if let savedTheme = UserDefaults.standard.string(forKey: themeKey),
           let theme = Theme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .amber // Default theme
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
    }

    var colors: ThemeColors {
        currentTheme.colors
    }
}

// Environment key for theme
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// Convenience view modifier
struct ThemedView: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.themeManager, themeManager)
    }
}

extension View {
    func withTheme() -> some View {
        modifier(ThemedView())
    }
}
