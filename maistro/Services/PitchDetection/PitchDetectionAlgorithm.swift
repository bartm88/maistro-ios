//
//  PitchDetectionAlgorithm.swift
//  maistro
//
//  Protocol for pitch detection algorithms enabling multiple implementations
//  and aggregate voting strategies.

import Foundation

/// Result from a single pitch detection algorithm
struct PitchEstimate: Equatable {
    /// Detected fundamental frequency in Hz
    let frequency: Double

    /// Confidence level of the detection (0.0 to 1.0)
    let confidence: Double

    /// Name of the algorithm that produced this estimate
    let algorithm: String

    /// Convert frequency to MIDI note number (fractional)
    var midiNote: Double {
        69.0 + 12.0 * log2(frequency / 440.0)
    }

    /// Get the nearest integer MIDI note
    var nearestMidiNote: Int {
        Int(round(midiNote))
    }

    /// Cents deviation from nearest note (-50 to +50)
    var centsDeviation: Double {
        (midiNote - round(midiNote)) * 100.0
    }
}

/// Protocol that all pitch detection algorithms must conform to
protocol PitchDetectionAlgorithm {
    /// Human-readable name of the algorithm
    var name: String { get }

    /// Detect pitch from audio samples
    /// - Parameters:
    ///   - samples: Array of audio samples (mono, normalized float)
    ///   - sampleRate: Sample rate in Hz
    ///   - minFrequency: Minimum detectable frequency in Hz
    ///   - maxFrequency: Maximum detectable frequency in Hz
    /// - Returns: PitchEstimate if pitch detected, nil otherwise
    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate?
}

/// Represents consensus from multiple pitch detection algorithms
struct AggregatePitchEstimate {
    /// The agreed-upon frequency (median of agreeing estimates)
    let frequency: Double

    /// Combined confidence based on agreement level
    let confidence: Double

    /// Individual estimates from each algorithm
    let estimates: [PitchEstimate]

    /// Number of algorithms that agreed on the pitch (within tolerance)
    let consensusCount: Int

    /// Total number of algorithms that attempted detection
    let totalAlgorithms: Int

    /// Whether majority consensus was reached
    var hasMajorityConsensus: Bool {
        consensusCount > totalAlgorithms / 2
    }

    /// Ratio of algorithms that agreed
    var consensusRatio: Double {
        Double(consensusCount) / Double(totalAlgorithms)
    }
}
