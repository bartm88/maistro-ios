//
//  AggregatePitchDetector.swift
//  maistro
//
//  Aggregates results from multiple pitch detection algorithms using majority voting.
//  Groups estimates by MIDI note and selects the most agreed-upon pitch.

import Foundation

/// Configuration for aggregate pitch detection
struct AggregateDetectorConfig {
    /// Maximum cents difference to consider two estimates as agreeing
    let centsTolerance: Double

    /// Minimum number of algorithms that must agree
    let minimumConsensus: Int

    /// Whether to require strict majority (> 50%)
    let requireMajority: Bool

    init(centsTolerance: Double, minimumConsensus: Int, requireMajority: Bool) {
        self.centsTolerance = centsTolerance
        self.minimumConsensus = minimumConsensus
        self.requireMajority = requireMajority
    }
}

struct AggregatePitchDetector: PitchDetectionAlgorithm {
    let name = "Aggregate"

    /// Individual pitch detection algorithms to use
    let algorithms: [PitchDetectionAlgorithm]

    /// Configuration for aggregation
    let config: AggregateDetectorConfig

    init(algorithms: [PitchDetectionAlgorithm], config: AggregateDetectorConfig) {
        self.algorithms = algorithms
        self.config = config
    }

    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate? {
        // Collect estimates from all algorithms
        var estimates: [PitchEstimate] = []

        for algorithm in algorithms {
            if let estimate = algorithm.detectPitch(
                samples: samples,
                sampleRate: sampleRate,
                minFrequency: minFrequency,
                maxFrequency: maxFrequency
            ) {
                estimates.append(estimate)
            }
        }

        // Need at least minimum consensus to proceed
        guard estimates.count >= config.minimumConsensus else {
            return nil
        }

        // Group estimates by proximity (cents tolerance)
        let groups = groupEstimatesByProximity(estimates: estimates)

        // Find the largest group (majority vote)
        guard let largestGroup = groups.max(by: { $0.count < $1.count }) else {
            return nil
        }

        // Check consensus requirements
        let consensusCount = largestGroup.count
        let totalWithEstimates = estimates.count

        if config.requireMajority {
            guard consensusCount > algorithms.count / 2 else {
                return nil
            }
        }

        guard consensusCount >= config.minimumConsensus else {
            return nil
        }

        // Calculate aggregate frequency (weighted median by confidence)
        let aggregateFrequency = computeWeightedMedian(estimates: largestGroup)

        // Calculate aggregate confidence
        let avgConfidence = largestGroup.reduce(0.0) { $0 + $1.confidence } / Double(largestGroup.count)
        let consensusBonus = Double(consensusCount) / Double(algorithms.count)
        let aggregateConfidence = avgConfidence * (0.5 + 0.5 * consensusBonus)

        return PitchEstimate(
            frequency: aggregateFrequency,
            confidence: aggregateConfidence,
            algorithm: name
        )
    }

    /// Group estimates that are within cents tolerance of each other
    private func groupEstimatesByProximity(estimates: [PitchEstimate]) -> [[PitchEstimate]] {
        var groups: [[PitchEstimate]] = []

        for estimate in estimates {
            var foundGroup = false

            for i in 0..<groups.count {
                // Check if estimate is within tolerance of any member of this group
                for member in groups[i] {
                    let centsDiff = abs(centsBetween(freq1: estimate.frequency, freq2: member.frequency))
                    if centsDiff <= config.centsTolerance {
                        groups[i].append(estimate)
                        foundGroup = true
                        break
                    }
                }
                if foundGroup { break }
            }

            if !foundGroup {
                groups.append([estimate])
            }
        }

        return groups
    }

    /// Calculate cents difference between two frequencies
    private func centsBetween(freq1: Double, freq2: Double) -> Double {
        return 1200.0 * log2(freq1 / freq2)
    }

    /// Compute weighted median frequency (weighted by confidence)
    private func computeWeightedMedian(estimates: [PitchEstimate]) -> Double {
        let sorted = estimates.sorted { $0.frequency < $1.frequency }
        let totalWeight = sorted.reduce(0.0) { $0 + $1.confidence }

        var cumulativeWeight = 0.0
        let halfWeight = totalWeight / 2.0

        for estimate in sorted {
            cumulativeWeight += estimate.confidence
            if cumulativeWeight >= halfWeight {
                return estimate.frequency
            }
        }

        // Fallback to simple median
        return sorted[sorted.count / 2].frequency
    }

    /// Get detailed aggregate result with all individual estimates
    func detectPitchWithDetails(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> AggregatePitchEstimate? {
        var estimates: [PitchEstimate] = []

        for algorithm in algorithms {
            if let estimate = algorithm.detectPitch(
                samples: samples,
                sampleRate: sampleRate,
                minFrequency: minFrequency,
                maxFrequency: maxFrequency
            ) {
                estimates.append(estimate)
            }
        }

        guard !estimates.isEmpty else {
            return nil
        }

        let groups = groupEstimatesByProximity(estimates: estimates)

        guard let largestGroup = groups.max(by: { $0.count < $1.count }) else {
            return nil
        }

        let consensusCount = largestGroup.count
        let aggregateFrequency = computeWeightedMedian(estimates: largestGroup)

        let avgConfidence = largestGroup.reduce(0.0) { $0 + $1.confidence } / Double(largestGroup.count)
        let consensusBonus = Double(consensusCount) / Double(algorithms.count)
        let aggregateConfidence = avgConfidence * (0.5 + 0.5 * consensusBonus)

        return AggregatePitchEstimate(
            frequency: aggregateFrequency,
            confidence: aggregateConfidence,
            estimates: estimates,
            consensusCount: consensusCount,
            totalAlgorithms: algorithms.count
        )
    }
}

/// Factory for creating standard algorithm configurations
enum PitchDetectorFactory {
    /// Create all available pitch detection algorithms with sensible defaults
    static func createAllAlgorithms() -> [PitchDetectionAlgorithm] {
        return [
            AutocorrelationPitchDetector(correlationThreshold: 0.8),
            YINPitchDetector(threshold: 0.15),
            McLeodPitchDetector(cutoff: 0.93, smallCutoff: 0.5),
            HarmonicProductSpectrumDetector(harmonics: 5, peakThreshold: 3.0),
            YAAPTPitchDetector(numHarmonics: 10, voicingThreshold: 0.4, shcThreshold: 0.3)
        ]
    }

    /// Create an aggregate detector with all algorithms and default config
    static func createAggregateDetector() -> AggregatePitchDetector {
        let config = AggregateDetectorConfig(
            centsTolerance: 50.0,
            minimumConsensus: 2,
            requireMajority: true
        )

        return AggregatePitchDetector(
            algorithms: createAllAlgorithms(),
            config: config
        )
    }

    /// Create specific algorithm by name
    static func createAlgorithm(named name: String) -> PitchDetectionAlgorithm? {
        switch name.lowercased() {
        case "autocorrelation":
            return AutocorrelationPitchDetector(correlationThreshold: 0.8)
        case "yin":
            return YINPitchDetector(threshold: 0.15)
        case "mcleod", "mpm":
            return McLeodPitchDetector(cutoff: 0.93, smallCutoff: 0.5)
        case "hps", "harmonicproductspectrum":
            return HarmonicProductSpectrumDetector(harmonics: 5, peakThreshold: 3.0)
        case "yaapt":
            return YAAPTPitchDetector(numHarmonics: 10, voicingThreshold: 0.4, shcThreshold: 0.3)
        default:
            return nil
        }
    }
}
