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

    // Tuner state
    @State private var selectedAlgorithm: PitchAlgorithmType = .aggregate
    @State private var isTunerActive = false
    @State private var pitchDetector: PitchDetector?

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
                // Pitch Detection Sandbox
                SandboxTunerSection(
                    selectedAlgorithm: $selectedAlgorithm,
                    isTunerActive: $isTunerActive,
                    pitchDetector: $pitchDetector
                )
                .padding(.horizontal)

                Divider()
                    .padding(.horizontal)

                // Sheet Music Display
                VStack(spacing: 8) {
                    Text("Sheet Music Preview")
                        .font(.headline)
                        .foregroundColor(themeManager.colors.textNeutral)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SheetMusicView(
                        notation: notation,
                        label: nil,
                        width: 340,
                        height: 120,
                        timeSignature: "4/4"
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
        .onDisappear {
            pitchDetector?.stop()
        }
    }
}

// MARK: - Sandbox Tuner Section

struct SandboxTunerSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedAlgorithm: PitchAlgorithmType
    @Binding var isTunerActive: Bool
    @Binding var pitchDetector: PitchDetector?

    var body: some View {
        VStack(spacing: 16) {
            Text("Pitch Detection")
                .font(.headline)
                .foregroundColor(themeManager.colors.textNeutral)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Algorithm selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Algorithm")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)

                Picker("Algorithm", selection: $selectedAlgorithm) {
                    ForEach(PitchAlgorithmType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeManager.colors.neutralAccent.opacity(0.3))
                .cornerRadius(8)
                .onChange(of: selectedAlgorithm) { _, _ in
                    if isTunerActive {
                        restartTuner()
                    }
                }
            }

            // Start/Stop button
            ThemedButton(
                isTunerActive ? "Stop Listening" : "Start Listening",
                type: isTunerActive ? .secondary : .primary,
                size: .medium
            ) {
                if isTunerActive {
                    stopTuner()
                } else {
                    startTuner()
                }
            }

            // Pitch display
            if let detector = pitchDetector, isTunerActive {
                VStack(spacing: 12) {
                    // Algorithm name
                    Text("Using: \(detector.algorithmName)")
                        .font(.caption)
                        .foregroundColor(themeManager.colors.textSecondary)

                    // Note display
                    Text(detector.currentPitch?.noteName ?? "--")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.colors.textNeutral)

                    // Frequency and cents
                    HStack(spacing: 24) {
                        VStack(spacing: 2) {
                            Text("Frequency")
                                .font(.caption2)
                                .foregroundColor(themeManager.colors.textSecondary)
                            Text(detector.currentPitch != nil
                                 ? String(format: "%.1f Hz", detector.currentPitch!.frequency)
                                 : "-- Hz")
                                .font(.callout.monospacedDigit())
                                .foregroundColor(themeManager.colors.textNeutral)
                        }

                        VStack(spacing: 2) {
                            Text("Cents")
                                .font(.caption2)
                                .foregroundColor(themeManager.colors.textSecondary)
                            Text(detector.currentPitch != nil
                                 ? String(format: "%+.0f¢", detector.currentPitch!.centsDeviation)
                                 : "--")
                                .font(.callout.monospacedDigit())
                                .foregroundColor(centsColor(detector.currentPitch?.centsDeviation))
                        }

                        VStack(spacing: 2) {
                            Text("Confidence")
                                .font(.caption2)
                                .foregroundColor(themeManager.colors.textSecondary)
                            Text(detector.currentPitch != nil
                                 ? String(format: "%.0f%%", detector.currentPitch!.confidence * 100)
                                 : "--%")
                                .font(.callout.monospacedDigit())
                                .foregroundColor(themeManager.colors.textNeutral)
                        }
                    }

                    // Tuning indicator bar
                    if let cents = detector.currentPitch?.centsDeviation {
                        TuningIndicatorBar(centsDeviation: cents)
                    }
                }
                .padding()
                .background(themeManager.colors.neutralAccent.opacity(0.2))
                .cornerRadius(12)
            } else if !isTunerActive {
                Text("Tap 'Start Listening' to test pitch detection algorithms")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeManager.colors.neutralAccent.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }

    private func centsColor(_ cents: Double?) -> Color {
        guard let cents = cents else { return themeManager.colors.textNeutral }
        let absCents = abs(cents)
        if absCents < 5 {
            return .green
        } else if absCents < 15 {
            return .yellow
        } else {
            return .red
        }
    }

    private func startTuner() {
        let algorithm = PitchDetectorFactory.createAlgorithm(
            type: selectedAlgorithm,
            enableTimingLogs: true
        )
        let config = PitchDetectorConfig(
            sampleRate: 44100.0,
            bufferSize: 4096,
            minFrequency: 60.0,
            maxFrequency: 2000.0
        )
        pitchDetector = PitchDetector(config: config, algorithm: algorithm)
        isTunerActive = true

        Task {
            await pitchDetector?.start()
        }
    }

    private func stopTuner() {
        pitchDetector?.stop()
        isTunerActive = false
    }

    private func restartTuner() {
        stopTuner()
        startTuner()
    }
}

// MARK: - Tuning Indicator Bar

struct TuningIndicatorBar: View {
    @EnvironmentObject var themeManager: ThemeManager
    let centsDeviation: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let center = width / 2
            let maxOffset = width / 2 - 4
            let offset = min(max(centsDeviation / 50.0, -1), 1) * maxOffset

            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(themeManager.colors.neutralAccent.opacity(0.3))

                // Center marker
                Rectangle()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: 2)
                    .position(x: center, y: geometry.size.height / 2)

                // Indicator
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 12, height: 12)
                    .position(x: center + offset, y: geometry.size.height / 2)
            }
        }
        .frame(height: 20)
    }

    private var indicatorColor: Color {
        let absCents = abs(centsDeviation)
        if absCents < 5 {
            return .green
        } else if absCents < 15 {
            return .yellow
        } else {
            return .red
        }
    }
}

#Preview {
    SandboxView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
