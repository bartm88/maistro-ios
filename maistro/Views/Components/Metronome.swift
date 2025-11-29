//
//  Metronome.swift
//  maistro
//

import SwiftUI
import AVFoundation

class MetronomeEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var tempo: Double = 120

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?

    var minTempo: Double = 40
    var maxTempo: Double = 220

    init() {
        setupAudio()
    }

    private func setupAudio() {
        // Create a simple click sound using AudioServices or prepare a sound file
        // For now, we'll use system sound
    }

    func start() {
        guard !isPlaying else { return }
        isPlaying = true
        scheduleTimer()
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
            stop()
            start()
        }
    }

    private func scheduleTimer() {
        let interval = 60.0 / tempo
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playTick()
        }
        // Play first tick immediately
        playTick()
    }

    private func playTick() {
        // Play system click sound
        AudioServicesPlaySystemSound(1104) // Tock sound
    }
}

struct Metronome: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var engine = MetronomeEngine()

    let initialTempo: Double
    let minTempo: Double
    let maxTempo: Double
    let metronomeAngle: Double
    let onTempoChange: ((Double) -> Void)?

    @State private var tempoText: String = ""
    @State private var pendulumRotation: Double = 0
    @State private var animateForward = true

    init(
        initialTempo: Double = 120,
        minTempo: Double = 40,
        maxTempo: Double = 220,
        metronomeAngle: Double = 75,
        onTempoChange: ((Double) -> Void)? = nil
    ) {
        self.initialTempo = initialTempo
        self.minTempo = minTempo
        self.maxTempo = maxTempo
        self.metronomeAngle = metronomeAngle
        self.onTempoChange = onTempoChange
    }

    var body: some View {
        VStack(spacing: 12) {
            // Metronome visual
            ZStack {
                // Arc background
                MetronomeArc(angle: metronomeAngle)
                    .stroke(themeManager.colors.primary, lineWidth: 32)
                    .frame(width: 100, height: 50)

                // Pendulum
                Rectangle()
                    .fill(themeManager.colors.textNeutral)
                    .frame(width: 3, height: 50)
                    .offset(y: -25)
                    .rotationEffect(.degrees(engine.isPlaying ? pendulumRotation : 0), anchor: .bottom)
                    .animation(
                        engine.isPlaying ?
                            .linear(duration: 60.0 / engine.tempo / 2).repeatForever(autoreverses: true) :
                            .default,
                        value: engine.isPlaying
                    )

                // Base
                Circle()
                    .fill(themeManager.colors.secondary)
                    .frame(width: 12, height: 12)
                    .offset(y: 25)
            }
            .frame(height: 80)
            .onTapGesture {
                engine.toggle()
                if engine.isPlaying {
                    pendulumRotation = metronomeAngle / 2
                } else {
                    pendulumRotation = 0
                }
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
                .frame(width: 80)
            }

            // Tempo display
            HStack(spacing: 4) {
                TextField("", text: $tempoText)
                    .frame(width: 40)
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
                    if engine.isPlaying {
                        pendulumRotation = metronomeAngle / 2
                    } else {
                        pendulumRotation = 0
                    }
                }
            )
        }
        .padding()
        .background(themeManager.colors.neutral)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.colors.neutralAccent, lineWidth: 1)
        )
        .shadow(radius: 5)
        .onAppear {
            engine.tempo = initialTempo
            engine.minTempo = minTempo
            engine.maxTempo = maxTempo
            tempoText = String(Int(initialTempo))
        }
    }
}

struct MetronomeArc: Shape {
    let angle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2

        let startAngle = Angle(degrees: -90 - angle / 2)
        let endAngle = Angle(degrees: -90 + angle / 2)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        return path
    }
}

#Preview {
    Metronome(
        initialTempo: 120,
        onTempoChange: { tempo in
            print("Tempo changed to: \(tempo)")
        }
    )
    .environmentObject(ThemeManager.shared)
}
