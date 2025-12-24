//
//  PitchDetector.swift
//  maistro
//
//  Microphone pitch detection using autocorrelation algorithm

import Foundation
import AVFoundation
import Combine

struct PitchDetectorConfig {
    let sampleRate: Double
    let bufferSize: Int
    let minFrequency: Double
    let maxFrequency: Double

    static func standard() -> PitchDetectorConfig {
        PitchDetectorConfig(
            sampleRate: 44100.0,
            bufferSize: 4096,
            minFrequency: 60.0,  // ~B1
            maxFrequency: 2000.0 // ~B6
        )
    }
}

struct PitchDetection {
    let frequency: Double
    let amplitude: Double
    let confidence: Double

    /// Convert frequency to deciHz (Hz * 10) for consistency with existing pitch system
    var deciHz: UInt32 {
        UInt32(frequency * 10)
    }

    /// Get the note name for this detected pitch
    var noteName: String {
        RawNote.deciHzToNoteName(deciHz)
    }

    /// Get cents deviation from the nearest note
    /// Positive = sharp, Negative = flat
    var centsDeviation: Double {
        let midiNote = 69.0 + 12.0 * log2(frequency / 440.0)
        let nearestMidi = round(midiNote)
        let centsFromNearest = (midiNote - nearestMidi) * 100.0
        return centsFromNearest
    }

    /// Get the target frequency (the nearest note's exact frequency)
    var targetFrequency: Double {
        let midiNote = 69.0 + 12.0 * log2(frequency / 440.0)
        let nearestMidi = round(midiNote)
        return 440.0 * pow(2.0, (nearestMidi - 69.0) / 12.0)
    }
}

@MainActor
class PitchDetector: ObservableObject {
    private let config: PitchDetectorConfig
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    @Published var isListening: Bool = false
    @Published var currentPitch: PitchDetection?
    @Published var hasPermission: Bool = false
    @Published var permissionDenied: Bool = false

    private var pitchSubject = PassthroughSubject<PitchDetection, Never>()
    var pitchPublisher: AnyPublisher<PitchDetection, Never> {
        pitchSubject.eraseToAnyPublisher()
    }

    init(config: PitchDetectorConfig) {
        self.config = config
    }

    func requestPermission() async {
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .granted:
                hasPermission = true
                permissionDenied = false
            case .denied:
                hasPermission = false
                permissionDenied = true
            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                hasPermission = granted
                permissionDenied = !granted
            @unknown default:
                hasPermission = false
                permissionDenied = true
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                hasPermission = true
                permissionDenied = false
            case .denied:
                hasPermission = false
                permissionDenied = true
            case .undetermined:
                await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        Task { @MainActor in
                            self.hasPermission = granted
                            self.permissionDenied = !granted
                            continuation.resume()
                        }
                    }
                }
            @unknown default:
                hasPermission = false
                permissionDenied = true
            }
        }
    }

    func start() async {
        if !hasPermission {
            await requestPermission()
        }
        guard hasPermission else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)

            audioEngine = AVAudioEngine()
            guard let engine = audioEngine else { return }

            inputNode = engine.inputNode
            guard let input = inputNode else { return }

            let format = input.outputFormat(forBus: 0)
            let sampleRate = format.sampleRate

            input.installTap(onBus: 0, bufferSize: UInt32(config.bufferSize), format: format) { [weak self] buffer, _ in
                guard let self = self else { return }
                self.processBuffer(buffer, sampleRate: sampleRate)
            }

            try engine.start()
            isListening = true
        } catch {
            print("PitchDetector: Failed to start audio engine: \(error)")
            isListening = false
        }
    }

    func stop() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isListening = false
        currentPitch = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("PitchDetector: Failed to deactivate audio session: \(error)")
        }
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Calculate RMS amplitude
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(frameLength))
        let amplitude = Double(rms)

        // Skip if too quiet
        guard amplitude > 0.01 else {
            Task { @MainActor in
                self.currentPitch = nil
            }
            return
        }

        // Detect pitch using autocorrelation
        if let (frequency, confidence) = detectPitch(samples: samples, sampleRate: sampleRate) {
            let detection = PitchDetection(
                frequency: frequency,
                amplitude: amplitude,
                confidence: confidence
            )

            Task { @MainActor in
                self.currentPitch = detection
                self.pitchSubject.send(detection)
            }
        } else {
            Task { @MainActor in
                self.currentPitch = nil
            }
        }
    }

    /// Autocorrelation-based pitch detection
    private func detectPitch(samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        let minPeriod = Int(sampleRate / config.maxFrequency)
        let maxPeriod = Int(sampleRate / config.minFrequency)

        guard maxPeriod < samples.count else { return nil }

        var bestCorrelation: Float = 0
        var bestPeriod: Int = 0

        // Autocorrelation
        for period in minPeriod..<maxPeriod {
            var correlation: Float = 0
            var energy1: Float = 0
            var energy2: Float = 0

            let windowSize = min(period * 2, samples.count - period)

            for i in 0..<windowSize {
                correlation += samples[i] * samples[i + period]
                energy1 += samples[i] * samples[i]
                energy2 += samples[i + period] * samples[i + period]
            }

            // Normalized correlation
            let normFactor = sqrt(energy1 * energy2)
            if normFactor > 0 {
                correlation /= normFactor
            }

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestPeriod = period
            }
        }

        // Require minimum correlation for confidence
        guard bestCorrelation > 0.8 && bestPeriod > 0 else { return nil }

        // Parabolic interpolation for sub-sample precision
        let frequency = sampleRate / Double(bestPeriod)

        return (frequency, Double(bestCorrelation))
    }

    deinit {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }
}
