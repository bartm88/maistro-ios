//
//  PitchDetector.swift
//  maistro
//
//  Microphone pitch detection with pluggable algorithm support

import Foundation
import AVFoundation
import Combine

struct PitchDetectorConfig {
    let sampleRate: Double
    let bufferSize: Int
    let minFrequency: Double
    let maxFrequency: Double

    init(sampleRate: Double, bufferSize: Int, minFrequency: Double, maxFrequency: Double) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
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
    private let algorithm: PitchDetectionAlgorithm
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    @Published var isListening: Bool = false
    @Published var currentPitch: PitchDetection?
    @Published var hasPermission: Bool = false
    @Published var permissionDenied: Bool = false

    /// Name of the algorithm being used
    var algorithmName: String { algorithm.name }

    private var pitchSubject = PassthroughSubject<PitchDetection, Never>()
    var pitchPublisher: AnyPublisher<PitchDetection, Never> {
        pitchSubject.eraseToAnyPublisher()
    }

    init(config: PitchDetectorConfig, algorithm: PitchDetectionAlgorithm) {
        self.config = config
        self.algorithm = algorithm
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

        // Detect pitch using the configured algorithm
        if let estimate = algorithm.detectPitch(
            samples: samples,
            sampleRate: sampleRate,
            minFrequency: config.minFrequency,
            maxFrequency: config.maxFrequency
        ) {
            let detection = PitchDetection(
                frequency: estimate.frequency,
                amplitude: amplitude,
                confidence: estimate.confidence
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

    deinit {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
    }
}
