//
//  SandboxView.swift
//  maistro
//

import SwiftUI

struct SandboxView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter
    @State private var showingThemeSheet = false

    @State private var notation: String = "C4/q, D4/q, E4/q, F4/q"
    @State private var notationInput: String = "C4/q, D4/q, E4/q, F4/q"

    let exampleNotations = [
        ("C Major Scale", "C4/q, D4/q, E4/q, F4/q, G4/q, A4/q, B4/q, C5/q"),
        ("Simple Melody", "E4/q, E4/q, F4/q, G4/q, G4/q, F4/q, E4/q, D4/q"),
        ("With Accidentals", "C4/q, C#4/q, D4/q, Eb4/q, E4/q, F#4/q, G4/q, Ab4/q"),
        ("Mixed Durations", "C4/h, D4/q, E4/q, F4/w"),
        ("Quarter Notes", "C4/q, D4/q, E4/q, F4/q"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Sheet Music Display
                VStack(spacing: 8) {
                    Text("Sheet Music Preview")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.textNeutral)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SheetMusicView(
                        notation: notation,
                        width: 340,
                        height: 120
                    )
                }
                .padding(.horizontal)

                // Notation Input
                VStack(spacing: 12) {
                    Text("Notation Input")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.textNeutral)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Enter notation...", text: $notationInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    ThemedButton(
                        "Render",
                        type: .primary,
                        size: .medium
                    ) {
                        notation = notationInput
                    }
                }
                .padding(.horizontal)

                // Example Presets
                VStack(spacing: 12) {
                    Text("Example Presets")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.textNeutral)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(exampleNotations, id: \.0) { name, notes in
                        Button {
                            notationInput = notes
                            notation = notes
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundColor(themeManager.colors.textNeutral)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(themeManager.colors.textNeutral.opacity(0.5))
                            }
                            .padding()
                            .background(themeManager.colors.neutralAccent.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                // Notation Format Help
                VStack(spacing: 8) {
                    Text("Notation Format")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.textNeutral)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Format: {pitch}{accidental?}{octave}/{duration}")
                            .font(.system(.caption, design: .monospaced))

                        Text("Pitches: C, D, E, F, G, A, B")
                            .font(.caption)
                        Text("Accidentals: # (sharp), b (flat), n (natural)")
                            .font(.caption)
                        Text("Octaves: 0-9 (middle C = C4)")
                            .font(.caption)
                        Text("Durations: w (whole), h (half), q (quarter), 8, 16")
                            .font(.caption)
                    }
                    .foregroundColor(themeManager.colors.textNeutral.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(themeManager.colors.neutralAccent.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .top) {
            AppHeaderView(
                title: "Sandbox",
                showBackButton: true,
                showSettingsButton: true,
                onBack: {
                    viewRouter.goBack()
                },
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
    SandboxView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
