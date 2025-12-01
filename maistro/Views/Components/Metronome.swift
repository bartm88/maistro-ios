//
//  Metronome.swift
//  maistro
//

import SwiftUI
import AVFoundation

class MetronomeEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var tempo: Double = 120
    @Published var beatPhase: Int = 0  // Alternates 0, 1, 0, 1... for left/right swing

    private var timer: Timer?
    private var audioEngine: AVAudioEngine?
    private var tonePlayer: AVAudioPlayerNode?
    private var beepBuffer: AVAudioPCMBuffer?

    var minTempo: Double = 40
    var maxTempo: Double = 220

    init() {
        setupAudio()
    }

    private func setupAudio() {
        audioEngine = AVAudioEngine()
        tonePlayer = AVAudioPlayerNode()

        guard let audioEngine = audioEngine, let tonePlayer = tonePlayer else { return }

        audioEngine.attach(tonePlayer)

        // Create beep buffer - 1000Hz sine wave for 100ms
        let sampleRate: Double = 44100
        let frequency: Double = 1000
        let duration: Double = 0.1
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData?[0] {
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / sampleRate
                // Sine wave with exponential decay envelope
                let envelope = exp(-time * 30) // Quick decay
                let sample = Float(sin(2.0 * .pi * frequency * time) * envelope * 0.5)
                channelData[frame] = sample
            }
        }

        beepBuffer = buffer

        audioEngine.connect(tonePlayer, to: audioEngine.mainMixerNode, format: format)

        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        beatPhase = 0
        scheduleTimer()
        playBeep()
    }

    func stop() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func toggle() {
        if isPlaying {
            stop()
        } else {
            start()
        }
    }

    func setTempo(_ newTempo: Double) {
        tempo = min(maxTempo, max(minTempo, newTempo))
        if isPlaying {
            // Restart timer with new tempo
            timer?.invalidate()
            scheduleTimer()
        }
    }

    private func scheduleTimer() {
        let interval = 60.0 / tempo
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        // Alternate beat phase for pendulum swing direction
        beatPhase = beatPhase == 0 ? 1 : 0
        playBeep()
    }

    private func playBeep() {
        guard let tonePlayer = tonePlayer, let buffer = beepBuffer else { return }

        // Stop any currently playing sound and play new beep
        tonePlayer.stop()
        tonePlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        tonePlayer.play()
    }

    deinit {
        audioEngine?.stop()
    }
}

struct Metronome: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var engine: MetronomeEngine

    let initialTempo: Double
    let minTempo: Double
    let maxTempo: Double
    let metronomeAngle: Double
    let scale: CGFloat
    let onTempoChange: ((Double) -> Void)?

    @State private var tempoText: String = ""

    // Scaled dimensions
    private var arcWidth: CGFloat { 80 * scale }
    private var arcHeight: CGFloat { 70 * scale }
    private var metronomeHeight: CGFloat { 80 * scale }
    private var pivotSize: CGFloat { 12 * scale }
    private var pivotOffset: CGFloat { 32 * scale }
    private var sliderWidth: CGFloat { 80 * scale }
    private var textFieldWidth: CGFloat { 40 * scale }

    init(
        engine: MetronomeEngine,
        initialTempo: Double,
        minTempo: Double,
        maxTempo: Double,
        metronomeAngle: Double,
        scale: CGFloat,
        onTempoChange: ((Double) -> Void)?
    ) {
        self.engine = engine
        self.initialTempo = initialTempo
        self.minTempo = minTempo
        self.maxTempo = maxTempo
        self.metronomeAngle = metronomeAngle
        self.scale = scale
        self.onTempoChange = onTempoChange
    }

    // Calculate pendulum rotation based on beat phase
    private var pendulumRotation: Double {
        guard engine.isPlaying else { return 0 }
        // Swing between -angle/2 and +angle/2
        return engine.beatPhase == 0 ? -metronomeAngle / 2 : metronomeAngle / 2
    }

    // Animation duration is one beat (time to swing from one side to the other)
    private var swingDuration: Double {
        60.0 / engine.tempo
    }

    var body: some View {
        VStack(spacing: 4 * scale) {
            // Metronome visual
            ZStack {
                // Arc background (pie slice)
                MetronomeArc(angle: metronomeAngle)
                    .fill(themeManager.colors.primary)
                    .frame(width: arcWidth, height: arcHeight)

                // Pendulum
                PendulumView(
                    rotation: pendulumRotation,
                    duration: swingDuration,
                    scale: scale,
                    color: themeManager.colors.textNeutral
                )

                // Base pivot point
                Circle()
                    .fill(themeManager.colors.secondary)
                    .frame(width: pivotSize, height: pivotSize)
                    .offset(y: pivotOffset)
            }
            .frame(height: metronomeHeight)
            .onTapGesture {
                engine.toggle()
            }

            // Tempo slider
            if onTempoChange != nil {
                Slider(
                    value: Binding(
                        get: { engine.tempo },
                        set: { newValue in
                            engine.setTempo(newValue)
                            onTempoChange?(newValue)
                        }
                    ),
                    in: minTempo...maxTempo
                )
                .accentColor(themeManager.colors.primary)
                .frame(width: sliderWidth)
            }

            // Tempo display
            HStack(spacing: 4) {
                TextField("", text: $tempoText)
                    .frame(width: textFieldWidth)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .background(Color.white)
                    .cornerRadius(4)
                    .onAppear {
                        tempoText = String(Int(engine.tempo))
                    }
                    .onChange(of: engine.tempo) { _, newValue in
                        tempoText = String(Int(newValue))
                    }
                    .onSubmit {
                        if let newTempo = Double(tempoText) {
                            engine.setTempo(newTempo)
                            onTempoChange?(engine.tempo)
                        }
                        tempoText = String(Int(engine.tempo))
                    }

                Text("BPM")
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textNeutral)
            }

            // Play/Stop button
            ThemedButton(
                systemName: engine.isPlaying ? "stop.fill" : "play.fill",
                type: engine.isPlaying ? .negative : .primary,
                size: .small,
                action: {
                    engine.toggle()
                }
            )
        }
        .onAppear {
            engine.tempo = initialTempo
            engine.minTempo = minTempo
            engine.maxTempo = maxTempo
            tempoText = String(Int(initialTempo))
        }
    }
}

// Separate view for pendulum to properly handle animation
struct PendulumView: View {
    let rotation: Double
    let duration: Double
    let scale: CGFloat
    let color: Color

    private var barHeight: CGFloat { 65 * scale }
    private var barWidth: CGFloat { 4 * scale }
    private var offsetY: CGFloat { 2 * scale }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: barWidth, height: barHeight)
            .offset(x: 0, y: offsetY)
            // Anchor at pivot point (6 from bottom)
            .rotationEffect(
                .degrees(rotation),
                anchor: UnitPoint(x: 0.5, y: (barHeight) / barHeight)
            )
            .animation(
                .linear(duration: duration),
                value: rotation
            )
    }
}

struct MetronomeArc: Shape {
    let angle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        // Scale radius based on the rect size (original was 66 for 80x70 frame)
        let radius: CGFloat = rect.width * 0.825

        let startAngle = Angle(degrees: -90 - angle / 2)
        let endAngle = Angle(degrees: -90 + angle / 2)

        // Start at center and draw pie slice
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

#Preview {
    Metronome(
        engine: MetronomeEngine(),
        initialTempo: 120,
        minTempo: 40,
        maxTempo: 260,
        metronomeAngle: 80,
        scale: 1.0,
        onTempoChange: { tempo in
            print("Tempo changed to: \(tempo)")
        }
    )
    .environmentObject(ThemeManager.shared)
}
