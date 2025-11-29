//
//  ThemedButton.swift
//  maistro
//

import SwiftUI

enum ButtonType {
    case primary
    case secondary
    case neutral
    case confirmation
    case negative
}

enum ButtonSize {
    case small      // Icon buttons (36x36)
    case medium     // Standard buttons
    case large      // Full-width action buttons with padding
    case container  // Container buttons - content defines sizing
}

struct ThemedButton<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager

    let type: ButtonType
    let size: ButtonSize
    let action: () -> Void
    let content: () -> Content
    let isDisabled: Bool
    let showShadow: Bool

    init(
        type: ButtonType = .primary,
        size: ButtonSize = .medium,
        isDisabled: Bool = false,
        showShadow: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.type = type
        self.size = size
        self.isDisabled = isDisabled
        self.showShadow = showShadow
        self.action = action
        self.content = content
    }

    private var backgroundColor: Color {
        if isDisabled { return Color.gray.opacity(0.3) }
        switch type {
        case .primary: return themeManager.colors.primary
        case .secondary: return themeManager.colors.secondary
        case .neutral: return themeManager.colors.neutral
        case .confirmation: return themeManager.colors.confirmation
        case .negative: return themeManager.colors.negative
        }
    }

    private var textColor: Color {
        if isDisabled { return Color.gray }
        switch type {
        case .primary: return themeManager.colors.textPrimary
        case .secondary: return themeManager.colors.textSecondary
        case .neutral: return themeManager.colors.textNeutral
        case .confirmation: return themeManager.colors.textConfirmation
        case .negative: return themeManager.colors.textNegative
        }
    }

    private var borderColor: Color {
        if isDisabled { return Color.gray.opacity(0.5) }
        switch type {
        case .primary: return themeManager.colors.primaryAccent
        case .secondary: return themeManager.colors.secondaryAccent
        case .neutral: return themeManager.colors.neutralAccent
        case .confirmation: return themeManager.colors.confirmationAccent
        case .negative: return themeManager.colors.negativeAccent
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 8
        case .medium: return 10
        case .large, .container: return 15
        }
    }

    private var borderWidth: CGFloat {
        switch size {
        case .small: return 1.5
        case .medium: return 1
        case .large, .container: return 2
        }
    }

    var body: some View {
        Button(action: action) {
            content()
                .foregroundColor(textColor)
                .modifier(SizeModifier(size: size))
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .shadow(radius: showShadow ? 5 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct SizeModifier: ViewModifier {
    let size: ButtonSize

    func body(content: Content) -> some View {
        switch size {
        case .small:
            content
                .frame(width: 36, height: 36)
        case .medium:
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        case .large:
            content
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        case .container:
            content
                .frame(maxWidth: .infinity)
        }
    }
}

// Convenience initializer for simple text buttons
extension ThemedButton where Content == Text {
    init(
        _ title: String,
        type: ButtonType = .primary,
        size: ButtonSize = .medium,
        isDisabled: Bool = false,
        showShadow: Bool = false,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.size = size
        self.isDisabled = isDisabled
        self.showShadow = showShadow
        self.action = action
        self.content = {
            Text(title)
                .font(size == .large ? .headline : .body)
        }
    }
}

// Convenience initializer for icon buttons
extension ThemedButton {
    init(
        systemName: String,
        type: ButtonType = .primary,
        size: ButtonSize = .small,
        isDisabled: Bool = false,
        showShadow: Bool = false,
        action: @escaping () -> Void
    ) where Content == AnyView {
        self.type = type
        self.size = size
        self.isDisabled = isDisabled
        self.showShadow = showShadow
        self.action = action
        let iconSize: Font = size == .small ? .title3 : .title2
        self.content = {
            AnyView(
                Image(systemName: systemName)
                    .font(iconSize)
            )
        }
    }
}

#Preview {
    VStack {
        ThemedButton("Primary", type: .primary, action: {})
        ThemedButton("Secondary", type: .secondary, action: {})
        ThemedButton("Confirmation", type: .confirmation, action: {})
        ThemedButton("Neutral", type: .neutral, action: {})
        ThemedButton("Negative", type: .negative, action: {})
    }
    .padding()
    .environmentObject(ThemeManager.shared)
}
