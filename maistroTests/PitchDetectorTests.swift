//
//  PitchDetectorTests.swift
//  maistroTests
//
//  Tests for pitch detection algorithms using sample audio files.
//  Tests run all sample files and verify that at least 75% are correctly detected.
//

import Testing
import Foundation
import AVFoundation
@testable import maistro

// MARK: - Test Result Types

struct PitchDetectionTestResult {
    let configDescription: String
    let correctCount: Int
    let totalCount: Int
    let failedFiles: [String]

    var accuracy: Double {
        guard totalCount > 0 else { return 0.0 }
        return Double(correctCount) / Double(totalCount)
    }

    var accuracyPercentage: Double {
        accuracy * 100.0
    }

    func printSummary() {
        print("\n=== Pitch Detection Test Results ===")
        print("Configuration: \(configDescription)")
        print("Correct: \(correctCount)/\(totalCount) (\(String(format: "%.1f", accuracyPercentage))%)")
        if !failedFiles.isEmpty {
            print("Failed files:")
            for file in failedFiles {
                print("  - \(file)")
            }
        }
        print("====================================\n")
    }
    
    func printShortSummary() {
        print("\n=== Pitch Detection Test Results ===")
        print("Configuration: \(configDescription)")
        print("Correct: \(correctCount)/\(totalCount) (\(String(format: "%.1f", accuracyPercentage))%)")
        print("====================================\n")
    }
}

// MARK: - WAV File Loading

struct WAVLoader {
    /// Maximum number of samples to load for pitch detection
    /// Pitch detection only needs a small buffer - loading full files causes O(n²) algorithms to hang
    static let maxSamplesToLoad = 8192

    /// Load audio samples from a WAV file
    /// Returns samples as an array of Float values normalized to [-1, 1]
    /// Only loads the first `maxSamplesToLoad` samples to keep pitch detection fast
    static func loadSamples(from url: URL, maxSamples: Int = maxSamplesToLoad) throws -> (samples: [Float], sampleRate: Double) {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate

        // Only load what we need for pitch detection
        let frameCount = min(AVAudioFrameCount(audioFile.length), AVAudioFrameCount(maxSamples))

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WAVLoaderError.bufferCreationFailed
        }

        try audioFile.read(into: buffer, frameCount: frameCount)

        guard let channelData = buffer.floatChannelData else {
            throw WAVLoaderError.noChannelData
        }

        // Use first channel (mono or left channel of stereo)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))

        return (samples, sampleRate)
    }

    enum WAVLoaderError: Error {
        case bufferCreationFailed
        case noChannelData
    }
}

// MARK: - Note Name Parsing

struct NoteParser {
    /// Parse a note name like "A4", "Ab3", "Db4" to expected frequency
    /// 'b' in note name means flat (e.g., Ab = A-flat = G#)
    static func parseNoteToFrequency(_ noteName: String) -> Double? {
        var remaining = noteName

        // Extract note letter (first character)
        guard let noteChar = remaining.first else { return nil }
        remaining.removeFirst()

        // Check for accidental (# or b)
        var accidental = 0
        if remaining.first == "#" {
            accidental = 1
            remaining.removeFirst()
        } else if remaining.first == "b" {
            accidental = -1
            remaining.removeFirst()
        }

        // Parse octave number
        guard let octave = Int(remaining) else { return nil }

        // Base note indices (C=0, D=2, E=4, F=5, G=7, A=9, B=11)
        let baseNoteIndex: Int
        switch noteChar {
        case "C": baseNoteIndex = 0
        case "D": baseNoteIndex = 2
        case "E": baseNoteIndex = 4
        case "F": baseNoteIndex = 5
        case "G": baseNoteIndex = 7
        case "A": baseNoteIndex = 9
        case "B": baseNoteIndex = 11
        default: return nil
        }

        // Calculate MIDI note number
        let noteIndex = baseNoteIndex + accidental
        let midiNote = (octave + 1) * 12 + noteIndex

        // Convert to frequency: A4 (MIDI 69) = 440Hz
        let frequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)

        return frequency
    }

    /// Parse note from filename (e.g., "Piano.ff.A4.wav" -> "A4", "Clarinet.Db4.wav" -> "Db4")
    static func extractNoteFromFilename(_ filename: String) -> String? {
        let components = filename.replacingOccurrences(of: ".wav", with: "").split(separator: ".")
        guard let lastComponent = components.last else { return nil }
        return String(lastComponent)
    }
}

// MARK: - Pitch Comparison

struct PitchComparison {
    /// Check if detected frequency matches expected within 50 cents (half semitone)
    static func frequenciesMatch(detected: Double, expected: Double, centsTolerance: Double = 50.0) -> Bool {
        let cents = 1200.0 * log2(detected / expected)
        return abs(cents) <= centsTolerance
    }
}

// MARK: - Test Helpers

struct PitchDetectorTestHelper {

    /// Run pitch detection on all sample files with the given detector
    static func runAllSamples<T: PitchDetectionAlgorithm>(
        detector: T,
        configDescription: String,
        sampleDirectoryPath: String,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchDetectionTestResult {
        let fileManager = FileManager.default
        var correctCount = 0
        var totalCount = 0
        var failedFiles: [String] = []

        // Find all subdirectories (piano, clarinet)
        guard let subdirs = try? fileManager.contentsOfDirectory(atPath: sampleDirectoryPath) else {
            return PitchDetectionTestResult(
                configDescription: configDescription,
                correctCount: 0,
                totalCount: 0,
                failedFiles: ["Could not read sample directory"]
            )
        }

        for subdir in subdirs where subdir != ".DS_Store" && subdir != "unprocessed" {
            let subdirPath = (sampleDirectoryPath as NSString).appendingPathComponent(subdir)

            guard let files = try? fileManager.contentsOfDirectory(atPath: subdirPath) else { continue }

            for filename in files where filename.hasSuffix(".wav") {
                totalCount += 1

                let filePath = (subdirPath as NSString).appendingPathComponent(filename)
                let fileURL = URL(fileURLWithPath: filePath)

                // Parse expected note from filename
                guard let noteName = NoteParser.extractNoteFromFilename(filename),
                      let expectedFrequency = NoteParser.parseNoteToFrequency(noteName) else {
                    failedFiles.append("\(subdir)/\(filename) (could not parse note name)")
                    continue
                }

                // Skip files outside the detector's frequency range
                if expectedFrequency < minFrequency || expectedFrequency > maxFrequency {
                    totalCount -= 1  // Don't count files outside range
                    continue
                }

                // Load audio samples
                guard let (samples, sampleRate) = try? WAVLoader.loadSamples(from: fileURL) else {
                    failedFiles.append("\(subdir)/\(filename) (could not load audio)")
                    continue
                }

                // Run pitch detection
                guard let estimate = detector.detectPitch(
                    samples: samples,
                    sampleRate: sampleRate,
                    minFrequency: minFrequency,
                    maxFrequency: maxFrequency
                ) else {
                    failedFiles.append("\(subdir)/\(filename) (no pitch detected, expected \(noteName))")
                    continue
                }

                // Check if detected pitch matches expected
                if PitchComparison.frequenciesMatch(detected: estimate.frequency, expected: expectedFrequency) {
                    correctCount += 1
                } else {
                    let detectedNoteName = frequencyToNoteName(estimate.frequency)
                    failedFiles.append("\(subdir)/\(filename) (expected \(noteName), detected \(detectedNoteName))")
                }
            }
        }

        return PitchDetectionTestResult(
            configDescription: configDescription,
            correctCount: correctCount,
            totalCount: totalCount,
            failedFiles: failedFiles
        )
    }

    /// Convert frequency to note name for debugging output
    private static func frequencyToNoteName(_ frequency: Double) -> String {
        let midiNote = 69.0 + 12.0 * log2(frequency / 440.0)
        let roundedMidi = Int(round(midiNote))
        let clampedMidi = max(0, min(127, roundedMidi))

        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[clampedMidi % 12]
        let octave = (clampedMidi / 12) - 1

        return "\(noteName)\(octave)"
    }
}

// MARK: - Test Configuration

struct TestPaths {
    static var sampleDirectory: String {
        // Get the path to the note_samples directory relative to the test bundle
        let testBundlePath = Bundle(for: BundleMarker.self).bundlePath
        let testsDirPath = (testBundlePath as NSString).deletingLastPathComponent
        return (testsDirPath as NSString).appendingPathComponent("maistroTests/note_samples")
    }

    /// Fallback to absolute path if bundle path doesn't work
    static var sampleDirectoryAbsolute: String {
        "/Users/michaelbartholomew/workspace/maistro/maistroTests/note_samples"
    }
}

/// Marker class to help find the test bundle
private class BundleMarker {}

// MARK: - Pitch Detector Tests

struct PitchDetectorTests {

    let samplePath = TestPaths.sampleDirectoryAbsolute
    let minFrequency = 60.0
    let maxFrequency = 2000.0
    let requiredAccuracy = 0.75

    // MARK: - Autocorrelation Tests

    @Test func testAutocorrelationPitchDetector() async throws {
        var bestRun: PitchDetectionTestResult? = nil
        for i in 1...9 {
            let correlationThreshold = Float(i) / 10.0
            let detector = AutocorrelationPitchDetector(correlationThreshold: correlationThreshold)
            
            let result = PitchDetectorTestHelper.runAllSamples(
                detector: detector,
                configDescription: "Autocorrelation (correlationThreshold: \(correlationThreshold))",
                sampleDirectoryPath: samplePath,
                minFrequency: minFrequency,
                maxFrequency: maxFrequency
            )
            if bestRun == nil || bestRun!.correctCount > result.correctCount {
                bestRun = result
            }
            result.printShortSummary()
        }
        bestRun?.printSummary()
    }

    // MARK: - YIN Tests

    @Test func testYINPitchDetector() async throws {
        var bestRun: PitchDetectionTestResult? = nil
        for i in 1...9 {
            let threshold = 0.1 + Double(i) / 100
            let detector = YINPitchDetector(threshold: threshold)

            let result = PitchDetectorTestHelper.runAllSamples(
                detector: detector,
                configDescription: "YIN (threshold: \(threshold))",
                sampleDirectoryPath: samplePath,
                minFrequency: minFrequency,
                maxFrequency: maxFrequency
            )

            if bestRun == nil || bestRun!.correctCount > result.correctCount {
                bestRun = result
            }
            result.printShortSummary()
        }
        bestRun?.printSummary()
    }

    // MARK: - McLeod Tests

    @Test func testMcLeodPitchDetector() async throws {
        var bestRun: PitchDetectionTestResult? = nil
        for i in 1...9 {
            for j in 1...9 {
                let cutoff = 0.9 + Double(i) / 100
                let smallCutoff = Double(j) / 10
                let detector = McLeodPitchDetector(cutoff: cutoff, smallCutoff: smallCutoff)
                
                let result = PitchDetectorTestHelper.runAllSamples(
                    detector: detector,
                    configDescription: "McLeod (cutoff: \(cutoff), smallCutoff: \(smallCutoff))",
                    sampleDirectoryPath: samplePath,
                    minFrequency: minFrequency,
                    maxFrequency: maxFrequency
                )
                
                
                if bestRun == nil || bestRun!.correctCount > result.correctCount {
                    bestRun = result
                }
                result.printShortSummary()
            }
        }
        bestRun?.printSummary()
    }

    // MARK: - HPS Tests

    @Test func testHPSPitchDetector() async throws {
        var bestRun: PitchDetectionTestResult? = nil
        for i in 2...9 {
            for j in 1...9 {
                let harmonics = i
                let peakThreshold = 2 + Double(j) / 50
                let detector = HarmonicProductSpectrumDetector(harmonics: harmonics, peakThreshold: peakThreshold)

                let result = PitchDetectorTestHelper.runAllSamples(
                    detector: detector,
                    configDescription: "HPS (harmonics: \(harmonics), peakThreshold: \(peakThreshold))",
                    sampleDirectoryPath: samplePath,
                    minFrequency: minFrequency,
                    maxFrequency: maxFrequency
                )

                if bestRun == nil || bestRun!.correctCount > result.correctCount {
                    bestRun = result
                }
                result.printShortSummary()
            }
        }
        bestRun?.printSummary()
    }

    // MARK: - YAAPT Tests

    @Test func testYAAPTPitchDetector() async throws {
        var bestRun: PitchDetectionTestResult? = nil
        for i in 2...13 {
            for j in 1...9 {
                for k in 1...9 {
                    let numHarmonics = i
                    let voicingThreshold = Double(j) / 10
                    let shcThreshold = Double(k) / 10
                    let detector = YAAPTPitchDetector(numHarmonics: numHarmonics, voicingThreshold: voicingThreshold, shcThreshold: shcThreshold)
                    
                    let result = PitchDetectorTestHelper.runAllSamples(
                        detector: detector,
                        configDescription: "YAAPT (numHarmonics: \(numHarmonics), voicingThreshold: \(voicingThreshold), shcThreshold: \(shcThreshold))",
                        sampleDirectoryPath: samplePath,
                        minFrequency: minFrequency,
                        maxFrequency: maxFrequency
                    )
                    
                    if bestRun == nil || bestRun!.correctCount > result.correctCount {
                        bestRun = result
                    }
                    result.printShortSummary()
                }
            }
        }
        bestRun?.printSummary()
    }

    // MARK: - Aggregate Tests

    @Test func testAggregatePitchDetector() async throws {
        let config = AggregateDetectorConfig(
            centsTolerance: 50.0,
            minimumConsensus: 2,
            requireMajority: true,
            enableTimingLogs: false
        )

        let algorithms: [PitchDetectionAlgorithm] = [
            AutocorrelationPitchDetector(correlationThreshold: 0.8),
            YINPitchDetector(threshold: 0.15),
            McLeodPitchDetector(cutoff: 0.93, smallCutoff: 0.5),
            HarmonicProductSpectrumDetector(harmonics: 5, peakThreshold: 3.0),
            YAAPTPitchDetector(numHarmonics: 10, voicingThreshold: 0.4, shcThreshold: 0.3)
        ]

        let detector = AggregatePitchDetector(algorithms: algorithms, config: config)

        let result = PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "Aggregate (centsTolerance: 50.0, minimumConsensus: 2, requireMajority: true)",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )

        result.printSummary()

        #expect(
            result.accuracy >= requiredAccuracy,
            "Aggregate accuracy \(String(format: "%.1f", result.accuracyPercentage))% is below required \(requiredAccuracy * 100)%"
        )
    }
}

// MARK: - Parameterized Test Helpers

/// Helper functions for running tests with custom parameters
/// Use these to experiment with different detector configurations

struct ParameterizedPitchDetectorTests {

    static let samplePath = TestPaths.sampleDirectoryAbsolute
    static let minFrequency = 60.0
    static let maxFrequency = 2000.0

    /// Test Autocorrelation with custom threshold
    static func testAutocorrelation(
        correlationThreshold: Float
    ) -> PitchDetectionTestResult {
        let detector = AutocorrelationPitchDetector(correlationThreshold: correlationThreshold)

        return PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "Autocorrelation (correlationThreshold: \(correlationThreshold))",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )
    }

    /// Test YIN with custom threshold
    static func testYIN(
        threshold: Double
    ) -> PitchDetectionTestResult {
        let detector = YINPitchDetector(threshold: threshold)

        return PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "YIN (threshold: \(threshold))",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )
    }

    /// Test McLeod with custom parameters
    static func testMcLeod(
        cutoff: Double,
        smallCutoff: Double
    ) -> PitchDetectionTestResult {
        let detector = McLeodPitchDetector(cutoff: cutoff, smallCutoff: smallCutoff)

        return PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "McLeod (cutoff: \(cutoff), smallCutoff: \(smallCutoff))",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )
    }

    /// Test HPS with custom parameters
    static func testHPS(
        harmonics: Int,
        peakThreshold: Double
    ) -> PitchDetectionTestResult {
        let detector = HarmonicProductSpectrumDetector(harmonics: harmonics, peakThreshold: peakThreshold)

        return PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "HPS (harmonics: \(harmonics), peakThreshold: \(peakThreshold))",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )
    }

    /// Test YAAPT with custom parameters
    static func testYAAPT(
        numHarmonics: Int,
        voicingThreshold: Double,
        shcThreshold: Double
    ) -> PitchDetectionTestResult {
        let detector = YAAPTPitchDetector(
            numHarmonics: numHarmonics,
            voicingThreshold: voicingThreshold,
            shcThreshold: shcThreshold
        )

        return PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "YAAPT (numHarmonics: \(numHarmonics), voicingThreshold: \(voicingThreshold), shcThreshold: \(shcThreshold))",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )
    }

    /// Test Aggregate with custom parameters
    static func testAggregate(
        centsTolerance: Double,
        minimumConsensus: Int,
        requireMajority: Bool,
        algorithms: [PitchDetectionAlgorithm]
    ) -> PitchDetectionTestResult {
        let config = AggregateDetectorConfig(
            centsTolerance: centsTolerance,
            minimumConsensus: minimumConsensus,
            requireMajority: requireMajority,
            enableTimingLogs: false
        )

        let detector = AggregatePitchDetector(algorithms: algorithms, config: config)

        return PitchDetectorTestHelper.runAllSamples(
            detector: detector,
            configDescription: "Aggregate (centsTolerance: \(centsTolerance), minimumConsensus: \(minimumConsensus), requireMajority: \(requireMajority))",
            sampleDirectoryPath: samplePath,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        )
    }
}
