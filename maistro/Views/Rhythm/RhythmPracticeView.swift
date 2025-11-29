//
//  RhythmPracticeView.swift
//  maistro
//

import SwiftUI

struct RhythmPracticeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter
    @State private var showingThemeSheet = false

    @State private var tempo: Double = 120
    @State private var measureCount: Int = 2
    @State private var timeSignature: String = "4/4"
    @State private var showSettings = false
    @State private var isTapping = false

    // Target passage for practice
    @State private var targetPassage: DiscretePassage?

    // Evaluation scores (placeholder for now)
    @State private var durationScore: Double = 0
    @State private var rhythmScore: Double = 0
    @State private var pitchScore: Double = 0

    private var parsedTimeSignature: TimeSignature {
        TimeSignature(string: timeSignature) ?? TimeSignature(4, 4)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Two-column layout: Evaluation chart | Controls + Metronome
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 8) {
                        
                        // Top row: 3 control buttons
                        HStack(spacing: 8) {
                            ThemedButton(
                                systemName: "arrow.counterclockwise",
                                type: .neutral,
                                size: .small,
                                action: clearAttempt
                            )
                            
                            ThemedButton(
                                systemName: "forward.fill",
                                type: .neutral,
                                size: .small,
                                action: newPassage
                            )
                            
                            ThemedButton(
                                systemName: "gearshape",
                                type: .neutral,
                                size: .small,
                                action: { showSettings = true }
                            )
                        }
                        // Column 1: Evaluation chart
                        EvaluationChartView(
                            durationScore: durationScore,
                            rhythmScore: rhythmScore,
                            pitchScore: pitchScore,
                            width: 230,
                            height: 153
                        )
                    }

                    // Column 2: Controls and Metronome
                    VStack(spacing: 16) {

                        // Bottom row: Metronome
                        Metronome(
                            initialTempo: tempo,
                            onTempoChange: { newTempo in
                                tempo = newTempo
                            }
                        )
                    }
                }
                .padding(.horizontal)

                // Sheet music displays
                VStack(spacing: 16) {
                    // Target passage
                    if let passage = targetPassage {
                        SheetMusicView(
                            passage: passage,
                            label: "Target",
                            timeSignature: timeSignature
                        )
                    } else {
                        SheetMusicView(
                            notation: "",
                            label: "Target",
                            timeSignature: timeSignature
                        )
                    }

                    // Played passage (placeholder for now - will show user's tapped rhythm)
                    SheetMusicView(
                        notation: "",
                        label: "Played",
                        timeSignature: timeSignature
                    )
                }
                .padding(.horizontal)

                // Tap button
                TapButton(
                    isTapping: $isTapping,
                    onTapDown: sendTapDown,
                    onTapUp: sendTapUp
                )
                .padding(.top, 20)
            }
            .padding(.vertical)
        }
        .safeAreaInset(edge: .top) {
            AppHeaderView(
                title: "Rhythm Practice",
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
        .sheet(isPresented: $showSettings) {
            RhythmSettingsSheet(
                measureCount: $measureCount,
                timeSignature: $timeSignature
            )
        }
        .onAppear {
            generateNewPassage()
        }
        .onChange(of: measureCount) { _, _ in
            generateNewPassage()
        }
        .onChange(of: timeSignature) { _, _ in
            generateNewPassage()
        }
    }

    private func clearAttempt() {
        durationScore = 0
        rhythmScore = 0
        pitchScore = 0
    }

    private func newPassage() {
        clearAttempt()
        generateNewPassage()
    }

    private func generateNewPassage() {
        targetPassage = PassageGenerator.shared.generatePassage(
            measureCount: measureCount,
            timeSignature: parsedTimeSignature,
            smallestSubdivision: 8
        )
    }

    private func sendTapDown() {
        // Send tap down to backend
    }

    private func sendTapUp() {
        // Send tap up to backend and get evaluation
        // For demo, set random scores
        durationScore = Double.random(in: 0.5...1.0)
        rhythmScore = Double.random(in: 0.5...1.0)
        pitchScore = Double.random(in: 0.5...1.0)
    }
}

struct TapButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isTapping: Bool
    let onTapDown: () -> Void
    let onTapUp: () -> Void

    var body: some View {
        Circle()
            .fill(isTapping ? themeManager.colors.primaryHover : themeManager.colors.primary)
            .frame(width: 80, height: 80)
            .overlay(
                Text("Tap")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.colors.textPrimary)
            )
            .overlay(
                Circle()
                    .stroke(themeManager.colors.primaryAccent, lineWidth: 3)
            )
            .shadow(radius: isTapping ? 2 : 8)
            .scaleEffect(isTapping ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isTapping)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isTapping {
                            isTapping = true
                            onTapDown()
                        }
                    }
                    .onEnded { _ in
                        isTapping = false
                        onTapUp()
                    }
            )
    }
}

struct RhythmSettingsSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @Binding var measureCount: Int
    @Binding var timeSignature: String

    let measureOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    let timeSignatureOptions = ["3/4", "4/4", "5/4", "6/8", "7/8", "9/8", "12/8"]

    var body: some View {
        NavigationView {
            Form {
                Section("Practice Settings") {
                    Picker("Measures", selection: $measureCount) {
                        ForEach(measureOptions, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }

                    Picker("Time Signature", selection: $timeSignature) {
                        ForEach(timeSignatureOptions, id: \.self) { sig in
                            Text(sig).tag(sig)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RhythmPracticeView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(ViewRouter())
}
