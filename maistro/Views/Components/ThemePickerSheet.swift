//
//  ThemePickerSheet.swift
//  maistro
//

import SwiftUI

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
                                    .overlay(Circle().stroke(theme.colors.primaryAccent, lineWidth: 1))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(theme.colors.secondary)
                                    .overlay(Circle().stroke(theme.colors.secondaryAccent, lineWidth: 1))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(theme.colors.neutral)
                                    .overlay(Circle().stroke(theme.colors.neutralAccent, lineWidth: 1))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(theme.colors.confirmation)
                                    .overlay(Circle().stroke(theme.colors.confirmationAccent, lineWidth: 1))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(theme.colors.negative)
                                    .overlay(Circle().stroke(theme.colors.negativeAccent, lineWidth: 1))
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
    ThemePickerSheet()
        .environmentObject(ThemeManager.shared)
}
