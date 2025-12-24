//
//  AutocorrelationPitchDetector.swift
//  maistro
//
//  Pitch detection using normalized autocorrelation.
//  Simple and fast, but can have octave errors with certain timbres.

import Foundation

struct AutocorrelationPitchDetector: PitchDetectionAlgorithm {
    let name = "Autocorrelation"

    /// Minimum correlation required to consider a valid pitch detection
    let correlationThreshold: Float

    init(correlationThreshold: Float) {
        self.correlationThreshold = correlationThreshold
    }

    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate? {
        let minPeriod = Int(sampleRate / maxFrequency)
        let maxPeriod = Int(sampleRate / minFrequency)

        guard maxPeriod < samples.count else { return nil }

        var bestCorrelation: Float = 0
        var bestPeriod: Int = 0

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

        guard bestCorrelation > correlationThreshold && bestPeriod > 0 else {
            return nil
        }

        // Parabolic interpolation for sub-sample precision
        let frequency = parabolicInterpolation(
            samples: samples,
            sampleRate: sampleRate,
            period: bestPeriod,
            minPeriod: minPeriod,
            maxPeriod: maxPeriod
        )

        return PitchEstimate(
            frequency: frequency,
            confidence: Double(bestCorrelation),
            algorithm: name
        )
    }

    /// Refine period estimate using parabolic interpolation
    private func parabolicInterpolation(
        samples: [Float],
        sampleRate: Double,
        period: Int,
        minPeriod: Int,
        maxPeriod: Int
    ) -> Double {
        guard period > minPeriod && period < maxPeriod - 1 else {
            return sampleRate / Double(period)
        }

        // Calculate correlation at period-1, period, period+1
        let correlations = [period - 1, period, period + 1].map { p -> Float in
            var correlation: Float = 0
            var energy1: Float = 0
            var energy2: Float = 0
            let windowSize = min(p * 2, samples.count - p)

            for i in 0..<windowSize {
                correlation += samples[i] * samples[i + p]
                energy1 += samples[i] * samples[i]
                energy2 += samples[i + p] * samples[i + p]
            }

            let normFactor = sqrt(energy1 * energy2)
            return normFactor > 0 ? correlation / normFactor : 0
        }

        let alpha = correlations[0]
        let beta = correlations[1]
        let gamma = correlations[2]

        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else {
            return sampleRate / Double(period)
        }

        let delta = 0.5 * (alpha - gamma) / denominator
        let refinedPeriod = Double(period) + Double(delta)

        return sampleRate / refinedPeriod
    }
}
