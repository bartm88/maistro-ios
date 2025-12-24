//
//  McLeodPitchDetector.swift
//  maistro
//
//  McLeod Pitch Method (MPM) from "A Smarter Way to Find Pitch" (2005).
//  Uses normalized squared difference function (NSDF) and key maxima detection.
//  Excellent for real-time musical pitch detection with low latency.

import Foundation

struct McLeodPitchDetector: PitchDetectionAlgorithm {
    let name = "McLeod"

    /// Ratio threshold for selecting peaks (0.8-0.95 typical)
    /// Higher values require stronger peaks relative to the maximum
    let cutoff: Double

    /// Minimum NSDF value to consider valid
    let smallCutoff: Double

    init(cutoff: Double, smallCutoff: Double) {
        self.cutoff = cutoff
        self.smallCutoff = smallCutoff
    }

    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate? {
        let minPeriod = Int(sampleRate / maxFrequency)
        let maxPeriod = min(Int(sampleRate / minFrequency), samples.count / 2)

        guard maxPeriod > minPeriod else { return nil }

        // Compute NSDF (Normalized Square Difference Function)
        let nsdf = computeNSDF(samples: samples, maxPeriod: maxPeriod)

        // Find key maxima (positive peaks after zero crossings)
        let keyMaxima = findKeyMaxima(nsdf: nsdf, minPeriod: minPeriod, maxPeriod: maxPeriod)

        guard !keyMaxima.isEmpty else { return nil }

        // Find the highest maximum
        let highestMax = keyMaxima.max { $0.value < $1.value }!

        guard highestMax.value >= smallCutoff else { return nil }

        // Select the first peak that exceeds cutoff * highestMax
        let threshold = cutoff * highestMax.value
        guard let selectedPeak = keyMaxima.first(where: { $0.value >= threshold }) else {
            return nil
        }

        // Parabolic interpolation for sub-sample precision
        let refinedPeriod = parabolicInterpolation(
            nsdf: nsdf,
            period: selectedPeak.index
        )

        let frequency = sampleRate / refinedPeriod
        let confidence = selectedPeak.value

        return PitchEstimate(
            frequency: frequency,
            confidence: confidence,
            algorithm: name
        )
    }

    /// Compute Normalized Square Difference Function
    /// NSDF(τ) = 2 * r(τ) / (m(0) + m(τ))
    /// where r(τ) is autocorrelation and m(τ) is the sum of squares
    private func computeNSDF(samples: [Float], maxPeriod: Int) -> [Double] {
        var nsdf = [Double](repeating: 0, count: maxPeriod + 1)

        // Precompute cumulative sum of squares for efficiency
        var cumSum = [Double](repeating: 0, count: samples.count + 1)
        for i in 0..<samples.count {
            cumSum[i + 1] = cumSum[i] + Double(samples[i] * samples[i])
        }

        for tau in 0...maxPeriod {
            var acf: Double = 0  // Autocorrelation
            let windowSize = samples.count - tau

            for i in 0..<windowSize {
                acf += Double(samples[i]) * Double(samples[i + tau])
            }

            // Sum of squares for both windows
            let m0 = cumSum[windowSize]  // First window
            let mTau = cumSum[samples.count] - cumSum[tau]  // Second window (shifted by tau)

            let denominator = m0 + mTau
            if denominator > 0 {
                nsdf[tau] = 2.0 * acf / denominator
            }
        }

        return nsdf
    }

    /// Find key maxima: positive peaks that occur after zero crossings
    private func findKeyMaxima(nsdf: [Double], minPeriod: Int, maxPeriod: Int) -> [(index: Int, value: Double)] {
        var keyMaxima: [(index: Int, value: Double)] = []
        var isPositive = false
        var maxIndex = 0
        var maxValue: Double = 0

        for i in minPeriod...maxPeriod {
            if nsdf[i] > 0 {
                if !isPositive {
                    // Just crossed zero from negative to positive
                    isPositive = true
                    maxIndex = i
                    maxValue = nsdf[i]
                } else if nsdf[i] > maxValue {
                    maxIndex = i
                    maxValue = nsdf[i]
                }
            } else if isPositive {
                // Just crossed zero from positive to negative
                // Record the maximum from the positive region
                keyMaxima.append((index: maxIndex, value: maxValue))
                isPositive = false
                maxValue = 0
            }
        }

        // Handle case where we end in a positive region
        if isPositive && maxValue > 0 {
            keyMaxima.append((index: maxIndex, value: maxValue))
        }

        return keyMaxima
    }

    /// Parabolic interpolation for sub-sample accuracy
    private func parabolicInterpolation(nsdf: [Double], period: Int) -> Double {
        guard period > 0 && period < nsdf.count - 1 else {
            return Double(period)
        }

        let alpha = nsdf[period - 1]
        let beta = nsdf[period]
        let gamma = nsdf[period + 1]

        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else {
            return Double(period)
        }

        // For NSDF we want to find the maximum, so formula is slightly different
        let delta = 0.5 * (alpha - gamma) / denominator

        return Double(period) + delta
    }
}
