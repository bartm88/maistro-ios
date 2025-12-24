//
//  YINPitchDetector.swift
//  maistro
//
//  YIN pitch detection algorithm (de Cheveigné & Kawahara, 2002).
//  Uses cumulative mean normalized difference function to reduce octave errors.
//  More robust than simple autocorrelation for musical signals.

import Foundation

struct YINPitchDetector: PitchDetectionAlgorithm {
    let name = "YIN"

    /// Threshold for the cumulative mean normalized difference function.
    /// Lower values are more selective (fewer false positives).
    /// Typical values: 0.10 to 0.15
    let threshold: Double

    init(threshold: Double) {
        self.threshold = threshold
    }

    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate? {
        let minPeriod = Int(sampleRate / maxFrequency)
        let maxPeriod = min(Int(sampleRate / minFrequency), samples.count / 2)

        guard maxPeriod > minPeriod && maxPeriod < samples.count / 2 else {
            return nil
        }

        // Step 1 & 2: Compute difference function
        let difference = computeDifferenceFunction(
            samples: samples,
            maxPeriod: maxPeriod
        )

        // Step 3: Cumulative mean normalized difference function
        let cmndf = computeCumulativeMeanNormalizedDifference(difference: difference)

        // Step 4: Absolute threshold
        guard let period = findPeriod(
            cmndf: cmndf,
            minPeriod: minPeriod,
            maxPeriod: maxPeriod
        ) else {
            return nil
        }

        // Step 5: Parabolic interpolation
        let refinedPeriod = parabolicInterpolation(cmndf: cmndf, period: period)

        let frequency = sampleRate / refinedPeriod

        // Calculate confidence as 1 - cmndf value at the detected period
        let confidence = 1.0 - cmndf[period]

        return PitchEstimate(
            frequency: frequency,
            confidence: confidence,
            algorithm: name
        )
    }

    /// Step 1 & 2: Compute the difference function d(τ)
    /// d(τ) = Σ (x[j] - x[j+τ])²
    private func computeDifferenceFunction(
        samples: [Float],
        maxPeriod: Int
    ) -> [Double] {
        var difference = [Double](repeating: 0, count: maxPeriod + 1)
        difference[0] = 0

        for tau in 1...maxPeriod {
            var sum: Double = 0
            let windowSize = samples.count - maxPeriod

            for j in 0..<windowSize {
                let delta = Double(samples[j]) - Double(samples[j + tau])
                sum += delta * delta
            }

            difference[tau] = sum
        }

        return difference
    }

    /// Step 3: Cumulative mean normalized difference function d'(τ)
    /// d'(τ) = d(τ) / ((1/τ) * Σ d(j)) for j in 1..τ
    /// d'(0) = 1
    private func computeCumulativeMeanNormalizedDifference(
        difference: [Double]
    ) -> [Double] {
        var cmndf = [Double](repeating: 0, count: difference.count)
        cmndf[0] = 1.0

        var runningSum: Double = 0

        for tau in 1..<difference.count {
            runningSum += difference[tau]

            if runningSum > 0 {
                cmndf[tau] = difference[tau] * Double(tau) / runningSum
            } else {
                cmndf[tau] = 1.0
            }
        }

        return cmndf
    }

    /// Step 4: Find the first period where cmndf dips below threshold
    /// and is a local minimum
    private func findPeriod(
        cmndf: [Double],
        minPeriod: Int,
        maxPeriod: Int
    ) -> Int? {
        var tau = minPeriod

        // Find first value below threshold
        while tau < maxPeriod {
            if cmndf[tau] < threshold {
                // Find the local minimum after crossing threshold
                while tau + 1 < maxPeriod && cmndf[tau + 1] < cmndf[tau] {
                    tau += 1
                }
                return tau
            }
            tau += 1
        }

        // If no value below threshold, find global minimum
        var minValue = Double.infinity
        var minIndex = minPeriod

        for i in minPeriod..<maxPeriod {
            if cmndf[i] < minValue {
                minValue = cmndf[i]
                minIndex = i
            }
        }

        // Only return if the minimum is reasonably low
        guard minValue < 0.5 else { return nil }

        return minIndex
    }

    /// Step 5: Parabolic interpolation for sub-sample accuracy
    private func parabolicInterpolation(cmndf: [Double], period: Int) -> Double {
        guard period > 0 && period < cmndf.count - 1 else {
            return Double(period)
        }

        let alpha = cmndf[period - 1]
        let beta = cmndf[period]
        let gamma = cmndf[period + 1]

        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else {
            return Double(period)
        }

        let delta = 0.5 * (alpha - gamma) / denominator

        return Double(period) + delta
    }
}
