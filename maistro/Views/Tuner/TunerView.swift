//
//  TunerView.swift
//  maistro
//
//  Instrument tuner with microphone pitch detection

import SwiftUI

struct TunerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter
    @StateObject private var pitchDetector = PitchDetector(
        config: PitchDetectorConfig(
            sampleRate: 44100.0,
            bufferSize: 4096,
            minFrequency: 60.0,
            maxFrequency: 2000.0
        ),
        algorithm: PitchDetectorFactory.createAggregateDetector()
    )
    @State private var showingThemeSheet = false

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let gaugeSize = min(screenWidth - 64, 350)

            VStack(spacing: 24) {
                Spacer()

                // Note name display
                NoteNameDisplay(
                    noteName: pitchDetector.currentPitch?.noteName,
                    targetFrequency: pitchDetector.currentPitch?.targetFrequency
                )

                // Speedometer gauge (vertical orientation, green points left when in tune)
                TunerGauge(
                    centsDeviation: pitchDetector.currentPitch?.centsDeviation ?? 0,
                    isActive: pitchDetector.currentPitch != nil,
                    size: gaugeSize
                )

                // Frequency display
                FrequencyDisplay(
                    frequency: pitchDetector.currentPitch?.frequency,
                    centsDeviation: pitchDetector.currentPitch?.centsDeviation
                )

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .top) {
            AppHeaderView(
                title: "Tuner",
                showBackButton: true,
                showSettingsButton: true,
                showAudioInputButton: false,
                onBack: {
                    pitchDetector.stop()
                    viewRouter.goBack()
                },
                onSettings: {
                    showingThemeSheet = true
                },
                onAudioInput: {}
            )
        }
        .background(
            themeManager.colors.neutral
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showingThemeSheet) {
            ThemePickerSheet()
        }
        .onAppear {
            Task {
                await pitchDetector.start()
            }
        }
        .onDisappear {
            pitchDetector.stop()
        }
        .alert("Microphone Access Required", isPresented: $pitchDetector.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to use the tuner.")
        }
    }
}

struct NoteNameDisplay: View {
    @EnvironmentObject var themeManager: ThemeManager
    let noteName: String?
    let targetFrequency: Double?

    var body: some View {
        VStack(spacing: 8) {
            Text(noteName ?? "--")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.colors.textNeutral)
                .frame(height: 110)

            if let freq = targetFrequency {
                Text(String(format: "%.1f Hz", freq))
                    .font(.title3)
                    .foregroundColor(themeManager.colors.textNeutral)
            } else {
                Text("-- Hz")
                    .font(.title3)
                    .foregroundColor(themeManager.colors.textNeutral)
            }
        }
    }
}

struct FrequencyDisplay: View {
    @EnvironmentObject var themeManager: ThemeManager
    let frequency: Double?
    let centsDeviation: Double?

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("Frequency")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
                Text(frequency != nil ? String(format: "%.1f Hz", frequency!) : "-- Hz")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.textSecondary)
            }

            VStack(spacing: 4) {
                Text("Cents")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
                Text(centsDeviation != nil ? String(format: "%+.0f¢", centsDeviation!) : "--")
                    .font(.headline)
                    .foregroundColor(themeManager.colors.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(themeManager.colors.secondary)
        .cornerRadius(12)
    }
}

#Preview {
    TunerView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
