//
//  RhythmPracticeView.swift
//  maistro
//

import SwiftUI
import Combine

struct RhythmPracticeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewRouter: ViewRouter
    @State private var showingThemeSheet = false

    @State private var tempo: Double = 120
    @State private var measureCount: Int = 2
    @State private var timeSignature: String = "4/4"
    @State private var smallestSubdivision: Int = 8
    @State private var tempoSubdivision: Int = 4
    @State private var showSettings = false
    @State private var isTapping = false

    // Shared metronome engine for compact and full views
    @StateObject private var metronomeEngine = MetronomeEngine()

    // Expandable section state
    @State private var isToolsExpanded: Bool = false
    @State private var hasInitializedExpandedState: Bool = false

    // Target passage for practice
    @State private var targetPassage: DiscretePassage?

    // Played passage (converted from raw input)
    @State private var playedPassage: DiscretePassage?
    @State private var rawPlayedPassage: RawPassage = RawPassage.empty()

    // Note input listener
    @State private var noteInputListener: NoteInputListener?
    @State private var cancellables = Set<AnyCancellable>()

    // Evaluation scores
    @State private var durationScore: Double = 0
    @State private var rhythmScore: Double = 0
    @State private var pitchScore: Double = 0

    private var parsedTimeSignature: TimeSignature {
        TimeSignature(string: timeSignature) ?? TimeSignature(4, 4)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            // Responsive sizing calculations
            let isCompact = screenWidth < 400
            let radarSize = min(max(screenWidth * 0.45, 140), 225)  // Min 140, max 225
            let metronomeScale = min(max(screenWidth / 400, 0.7), 1.0)  // Scale 0.7-1.0
            let sheetMusicWidth = min(screenWidth - 40, 600)  // Max 600 for iPad
            let tapButtonSize = min(max(screenWidth * 0.18, 60), 80)  // Min 60, max 80
            let compactButtonSize: CGFloat = 44

            ScrollView {
                VStack(spacing: 16) {
                    // Expandable tools section
                    ExpandableSection(
                        isExpanded: $isToolsExpanded,
                        expandIconSize: 20,
                        compactContent: {
                            // Compact score view
                            CompactScoreView(
                                scores: [durationScore, rhythmScore, pitchScore],
                                size: compactButtonSize,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isToolsExpanded = true
                                    }
                                }
                            )

                            // Control buttons
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

                            // Compact metronome button
                            CompactMetronomeButton(
                                engine: metronomeEngine,
                                size: compactButtonSize,
                                onTap: nil
                            )
                        },
                        expandedContent: {
                            // Full expanded view
                            if isCompact {
                                // Compact layout: stack vertically
                                VStack(spacing: 12) {
                                    // Row 1: Radar chart and controls side by side
                                    HStack(alignment: .top, spacing: 12) {
                                        // Evaluation chart
                                        RadarChartView(
                                            dataPoints: [
                                                RadarChartDataPoint(id: "duration", label: "Duration", score: durationScore),
                                                RadarChartDataPoint(id: "rhythm", label: "Rhythm", score: rhythmScore),
                                                RadarChartDataPoint(id: "pitch", label: "Pitch", score: pitchScore)
                                            ],
                                            size: radarSize,
                                            labelPadding: 8,
                                            onAxisTapped: nil
                                        )
                                        .padding(8)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                        .background(themeManager.colors.neutral)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
                                        )

                                        // Controls and Metronome
                                        VStack(spacing: 8) {
                                            // Control buttons
                                            HStack(spacing: 6) {
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

                                            // Metronome
                                            Metronome(
                                                engine: metronomeEngine,
                                                initialTempo: tempo,
                                                minTempo: 40,
                                                maxTempo: 260,
                                                metronomeAngle: 80,
                                                scale: metronomeScale,
                                                onTempoChange: { newTempo in
                                                    tempo = newTempo
                                                }
                                            )
                                            .padding(.horizontal, 16 * metronomeScale)
                                            .padding(.vertical, 6)
                                            .background(themeManager.colors.neutral)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            } else {
                                // Regular layout: side by side with more spacing
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(spacing: 8) {
                                        // Column 1: Evaluation chart
                                        RadarChartView(
                                            dataPoints: [
                                                RadarChartDataPoint(id: "duration", label: "Duration", score: durationScore),
                                                RadarChartDataPoint(id: "rhythm", label: "Rhythm", score: rhythmScore),
                                                RadarChartDataPoint(id: "pitch", label: "Pitch", score: pitchScore)
                                            ],
                                            size: radarSize,
                                            labelPadding: 10,
                                            onAxisTapped: nil
                                        )
                                        .padding(12)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                        .background(themeManager.colors.neutral)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
                                        )
                                    }

                                    // Column 2: Controls and Metronome
                                    VStack(spacing: 16) {
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
                                        // Bottom row: Metronome
                                        Metronome(
                                            engine: metronomeEngine,
                                            initialTempo: tempo,
                                            minTempo: 40,
                                            maxTempo: 260,
                                            metronomeAngle: 80,
                                            scale: metronomeScale,
                                            onTempoChange: { newTempo in
                                                tempo = newTempo
                                            }
                                        )
                                        .padding(.horizontal, 24 * metronomeScale)
                                        .padding(.vertical, 8)
                                        .background(themeManager.colors.neutral)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                    )
                    .padding(.horizontal, isCompact ? 12 : 16)

                    // Sheet music displays
                    VStack(spacing: 16) {
                        // Target passage
                        if let passage = targetPassage {
                            SheetMusicView(
                                passage: passage,
                                label: "Target",
                                timeSignature: timeSignature,
                                maxWidth: sheetMusicWidth
                            )
                        } else {
                            SheetMusicView(
                                notation: "",
                                label: "Target",
                                width: min(300, sheetMusicWidth),
                                height: 120,
                                timeSignature: timeSignature
                            )
                        }

                        // Played passage
                        SheetMusicView(
                            passage: playedPassage ?? DiscretePassage.blank(
                                measureCount: measureCount,
                                subdivisionDenominator: smallestSubdivision
                            ),
                            label: "Played",
                            timeSignature: timeSignature,
                            maxWidth: sheetMusicWidth
                        )
                    }
                    .padding(.horizontal, isCompact ? 12 : 16)

                    // Tap button
                    TapButton(
                        isTapping: $isTapping,
                        size: tapButtonSize,
                        onTapDown: sendTapDown,
                        onTapUp: sendTapUp
                    )
                    .padding(.top, 16)
                }
                .padding(.vertical)
            }
            .onAppear {
                // Set default expanded state based on screen size
                if !hasInitializedExpandedState {
                    isToolsExpanded = !isCompact
                    hasInitializedExpandedState = true
                }
            }
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
                timeSignature: $timeSignature,
                smallestSubdivision: $smallestSubdivision,
                tempoSubdivision: $tempoSubdivision
            )
        }
        .onAppear {
            generateNewPassage()
            setupNoteInputListener()
        }
        .onChange(of: measureCount) { _, _ in
            newPassage()
        }
        .onChange(of: timeSignature) { _, _ in
            newPassage()
        }
        .onChange(of: smallestSubdivision) { _, _ in
            newPassage()
        }
    }

    private func clearAttempt() {
        durationScore = 0
        rhythmScore = 0
        pitchScore = 0
        playedPassage = nil
        rawPlayedPassage = RawPassage.empty()

        Task {
            await noteInputListener?.clear()
        }
    }

    private func newPassage() {
        clearAttempt()
        generateNewPassage()
    }

    private func generateNewPassage() {
        targetPassage = PassageGenerator.shared.generatePassage(
            measureCount: measureCount,
            timeSignature: parsedTimeSignature,
            smallestSubdivision: smallestSubdivision
        )
    }

    private func setupNoteInputListener() {
        let config = NoteInputListenerConfig.rhythmPractice()
        let listener = NoteInputListener(config: config)
        noteInputListener = listener

        // Subscribe to passage updates
        listener.passagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [self] passage in
                rawPlayedPassage = passage
                updatePlayedPassage()
                evaluatePassage()
            }
            .store(in: &cancellables)
    }

    private func updatePlayedPassage() {
        let snapperConfig = SnapperConfig(
            tempo: tempo,
            tempoSubdivision: tempoSubdivision,
            subdivisionResolution: smallestSubdivision,
            timeSignature: parsedTimeSignature
        )
        let snapper = SubdivisionSnapper(config: snapperConfig)
        let converter = RawToDiscreteConverter(snapper: snapper)

        playedPassage = converter.convert(
            rawPassage: rawPlayedPassage,
            measureCount: measureCount,
            noteName: "B4"
        )
    }

    private func evaluatePassage() {
        guard let target = targetPassage else { return }

        let context = EvaluationContext(
            tempo: tempo,
            tempoSubdivision: tempoSubdivision,
            subdivisionResolution: smallestSubdivision
        )

        let evaluator = PassageEvaluator(context: context)
        let result = evaluator.evaluate(
            expected: target,
            actual: rawPlayedPassage,
            timeSignature: parsedTimeSignature
        )

        rhythmScore = result.rhythmScore
        // Duration and pitch scores would come from additional evaluators
        // For now, set placeholder values based on rhythm score
        durationScore = rhythmScore * 0.9 + 0.1
        pitchScore = 1.0 // Pitch is always correct for tap input
    }

    private func sendTapDown() {
        let timestampMs = NoteInputListener.currentTimestampMs()
        Task {
            await noteInputListener?.noteStarted(timestampMs: timestampMs)
        }
    }

    private func sendTapUp() {
        let timestampMs = NoteInputListener.currentTimestampMs()
        Task {
            await noteInputListener?.noteEnded(timestampMs: timestampMs)
        }
    }
}

struct TapButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isTapping: Bool
    let size: CGFloat
    let onTapDown: () -> Void
    let onTapUp: () -> Void

    var body: some View {
        Circle()
            .fill(isTapping ? themeManager.colors.primaryHover : themeManager.colors.primary)
            .frame(width: size, height: size)
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
    @Binding var smallestSubdivision: Int
    @Binding var tempoSubdivision: Int

    let measureOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    let timeSignatureOptions = ["3/4", "4/4", "5/4", "6/8", "7/8", "9/8", "12/8"]
    let noteSubdivisionOptions: [(value: Int, label: String)] = [
        (4, "Quarter Notes"),
        (8, "Eighth Notes"),
        (16, "Sixteenth Notes"),
        (32, "Thirty-Second Notes")
    ]
    let tempoSubdivisionOptions: [(value: Int, label: String)] = [
        (2, "Half Notes"),
        (4, "Quarter Notes"),
        (8, "Eighth Notes"),
        (16, "Sixteenth Notes")
    ]

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

                    Picker("Note Subdivision", selection: $smallestSubdivision) {
                        ForEach(noteSubdivisionOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
                        }
                    }

                    Picker("Tempo Subdivision", selection: $tempoSubdivision) {
                        ForEach(tempoSubdivisionOptions, id: \.value) { option in
                            Text(option.label).tag(option.value)
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
