//
//  YAAPTPitchDetector.swift
//  maistro
//
//  YAAPT-inspired pitch detection (Zahorian & Hu, 2008).
//  Combines spectral harmonic correlation with energy-based voicing detection.
//  Well-suited for vocal pitch tracking.

import Accelerate
import Foundation

struct YAAPTPitchDetector: PitchDetectionAlgorithm {
    let name = "YAAPT"

    /// Number of harmonics to use in spectral correlation
    let numHarmonics: Int

    /// Voicing threshold (ratio of low-frequency to total energy)
    let voicingThreshold: Double

    /// Minimum spectral harmonic correlation value
    let shcThreshold: Double

    init(numHarmonics: Int, voicingThreshold: Double, shcThreshold: Double) {
        self.numHarmonics = numHarmonics
        self.voicingThreshold = voicingThreshold
        self.shcThreshold = shcThreshold
    }

    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate? {
        let fftSize = nextPowerOfTwo(samples.count)
        guard fftSize >= 512 else { return nil }

        // Step 1: Apply window and compute spectrum
        var windowedSamples = applyHanningWindow(samples: samples, fftSize: fftSize)

        guard let magnitudes = computeMagnitudeSpectrum(samples: &windowedSamples, fftSize: fftSize) else {
            return nil
        }

        let binWidth = sampleRate / Double(fftSize)

        // Step 2: Normalized Low Frequency Energy Ratio (NLFER) for voicing
        let nlfer = computeNLFER(magnitudes: magnitudes, binWidth: binWidth, maxVoicedFreq: 1500.0)
        guard nlfer > voicingThreshold else {
            return nil
        }

        // Step 3: Spectral Harmonic Correlation (SHC)
        guard let (frequency, shcValue) = computeSHC(
            magnitudes: magnitudes,
            binWidth: binWidth,
            minFrequency: minFrequency,
            maxFrequency: maxFrequency
        ) else {
            return nil
        }

        guard shcValue > shcThreshold else {
            return nil
        }

        // Step 4: Refine with autocorrelation
        let refinedFrequency = refineWithAutocorrelation(
            samples: samples,
            sampleRate: sampleRate,
            initialEstimate: frequency
        )

        // Confidence combines SHC and NLFER
        let confidence = min(1.0, shcValue * nlfer)

        return PitchEstimate(
            frequency: refinedFrequency,
            confidence: confidence,
            algorithm: name
        )
    }

    /// Normalized Low Frequency Energy Ratio
    private func computeNLFER(magnitudes: [Float], binWidth: Double, maxVoicedFreq: Double) -> Double {
        let maxBin = min(Int(maxVoicedFreq / binWidth), magnitudes.count)

        var lowEnergy: Double = 0
        var totalEnergy: Double = 0

        for i in 0..<magnitudes.count {
            let energy = Double(magnitudes[i] * magnitudes[i])
            totalEnergy += energy
            if i < maxBin {
                lowEnergy += energy
            }
        }

        guard totalEnergy > 0 else { return 0 }

        return lowEnergy / totalEnergy
    }

    /// Spectral Harmonic Correlation
    /// Finds F0 that maximizes correlation of spectrum with harmonic template
    private func computeSHC(
        magnitudes: [Float],
        binWidth: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> (frequency: Double, value: Double)? {
        // Candidate F0 values (in Hz)
        let frequencyStep = 1.0  // 1 Hz resolution
        let numCandidates = Int((maxFrequency - minFrequency) / frequencyStep)

        var bestFrequency: Double = 0
        var bestSHC: Double = 0

        for i in 0..<numCandidates {
            let f0 = minFrequency + Double(i) * frequencyStep

            var shc: Double = 0

            // Sum energy at harmonic frequencies
            for h in 1...numHarmonics {
                let harmonicFreq = f0 * Double(h)
                let bin = Int(harmonicFreq / binWidth)

                if bin < magnitudes.count {
                    // Weight by inverse harmonic number (lower harmonics more important)
                    let weight = 1.0 / Double(h)
                    shc += weight * Double(magnitudes[bin])
                }
            }

            if shc > bestSHC {
                bestSHC = shc
                bestFrequency = f0
            }
        }

        guard bestSHC > 0 else { return nil }

        // Normalize SHC to 0-1 range
        let maxPossibleSHC = (1...numHarmonics).reduce(0.0) { $0 + 1.0 / Double($1) }
        let normalizedSHC = min(1.0, bestSHC / (maxPossibleSHC * Double(magnitudes.max() ?? 1)))

        return (bestFrequency, normalizedSHC)
    }

    /// Refine frequency estimate using local autocorrelation
    private func refineWithAutocorrelation(
        samples: [Float],
        sampleRate: Double,
        initialEstimate: Double
    ) -> Double {
        let expectedPeriod = Int(sampleRate / initialEstimate)

        // Search around expected period (+/- 10%)
        let searchRadius = max(2, expectedPeriod / 10)
        let minPeriod = max(2, expectedPeriod - searchRadius)
        let maxPeriod = min(samples.count / 2, expectedPeriod + searchRadius)

        var bestCorrelation: Float = -1
        var bestPeriod = expectedPeriod

        for period in minPeriod...maxPeriod {
            var correlation: Float = 0
            var energy1: Float = 0
            var energy2: Float = 0

            let windowSize = min(period * 2, samples.count - period)
            guard windowSize > 0 else { continue }

            for i in 0..<windowSize {
                correlation += samples[i] * samples[i + period]
                energy1 += samples[i] * samples[i]
                energy2 += samples[i + period] * samples[i + period]
            }

            let normFactor = sqrt(energy1 * energy2)
            if normFactor > 0 {
                correlation /= normFactor
            }

            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestPeriod = period
            }
        }

        return sampleRate / Double(bestPeriod)
    }

    private func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    private func applyHanningWindow(samples: [Float], fftSize: Int) -> [Float] {
        var result = [Float](repeating: 0, count: fftSize)

        for i in 0..<samples.count {
            let window = Float(0.5 * (1 - cos(2 * Double.pi * Double(i) / Double(samples.count - 1))))
            result[i] = samples[i] * window
        }

        return result
    }

    private func computeMagnitudeSpectrum(samples: inout [Float], fftSize: Int) -> [Float]? {
        let n = samples.count
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realp = [Float](repeating: 0, count: n / 2)
        var imagp = [Float](repeating: 0, count: n / 2)

        samples.withUnsafeBufferPointer { samplesPtr in
            realp.withUnsafeMutableBufferPointer { realpPtr in
                imagp.withUnsafeMutableBufferPointer { imagpPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: realpPtr.baseAddress!,
                        imagp: imagpPtr.baseAddress!
                    )
                    vDSP_ctoz(
                        UnsafePointer<DSPComplex>(OpaquePointer(samplesPtr.baseAddress!)),
                        2,
                        &splitComplex,
                        1,
                        vDSP_Length(n / 2)
                    )
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }
        }

        var magnitudes = [Float](repeating: 0, count: n / 2)

        realp.withUnsafeBufferPointer { realpPtr in
            imagp.withUnsafeBufferPointer { imagpPtr in
                magnitudes.withUnsafeMutableBufferPointer { magPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: UnsafeMutablePointer(mutating: realpPtr.baseAddress!),
                        imagp: UnsafeMutablePointer(mutating: imagpPtr.baseAddress!)
                    )
                    vDSP_zvabs(&splitComplex, 1, magPtr.baseAddress!, 1, vDSP_Length(n / 2))
                }
            }
        }

        return magnitudes
    }
}
