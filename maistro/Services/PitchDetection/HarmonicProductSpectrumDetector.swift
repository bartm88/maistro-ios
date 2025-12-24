//
//  HarmonicProductSpectrumDetector.swift
//  maistro
//
//  Harmonic Product Spectrum (HPS) pitch detection.
//  Frequency-domain algorithm that multiplies downsampled magnitude spectra.
//  Good for harmonic signals with strong overtones.

import Accelerate
import Foundation

struct HarmonicProductSpectrumDetector: PitchDetectionAlgorithm {
    let name = "HPS"

    /// Number of harmonic products to compute (2-5 typical)
    let harmonics: Int

    /// Minimum peak prominence relative to mean
    let peakThreshold: Double

    init(harmonics: Int, peakThreshold: Double) {
        self.harmonics = harmonics
        self.peakThreshold = peakThreshold
    }

    func detectPitch(
        samples: [Float],
        sampleRate: Double,
        minFrequency: Double,
        maxFrequency: Double
    ) -> PitchEstimate? {
        // Ensure power of 2 for FFT
        let fftSize = nextPowerOfTwo(samples.count)
        guard fftSize >= 256 else { return nil }

        // Apply Hanning window and zero-pad
        var windowedSamples = applyHanningWindow(samples: samples, fftSize: fftSize)

        // Compute magnitude spectrum
        guard let magnitudes = computeMagnitudeSpectrum(samples: &windowedSamples) else {
            return nil
        }

        // Frequency resolution
        let binWidth = sampleRate / Double(fftSize)

        // Bin indices for frequency range
        let minBin = max(1, Int(minFrequency / binWidth))
        let maxBin = min(magnitudes.count / harmonics, Int(maxFrequency / binWidth))

        guard maxBin > minBin else { return nil }

        // Compute harmonic product spectrum
        var hps = [Double](repeating: 1.0, count: maxBin)

        for bin in minBin..<maxBin {
            var product: Double = 1.0

            for h in 1...harmonics {
                let harmonicBin = bin * h
                if harmonicBin < magnitudes.count {
                    product *= Double(magnitudes[harmonicBin]) + 1e-10
                }
            }

            hps[bin] = product
        }

        // Find peak in HPS
        guard let (peakBin, peakValue) = findPeak(
            hps: hps,
            minBin: minBin,
            maxBin: maxBin
        ) else {
            return nil
        }

        // Check if peak is significant
        let meanValue = hps[minBin..<maxBin].reduce(0, +) / Double(maxBin - minBin)
        guard peakValue > meanValue * peakThreshold else {
            return nil
        }

        // Parabolic interpolation for sub-bin accuracy
        let refinedBin = parabolicInterpolation(hps: hps, bin: peakBin)

        let frequency = refinedBin * binWidth

        // Confidence based on peak prominence
        let confidence = min(1.0, peakValue / (meanValue * peakThreshold * 2))

        return PitchEstimate(
            frequency: frequency,
            confidence: confidence,
            algorithm: name
        )
    }

    /// Find next power of 2 >= n
    private func nextPowerOfTwo(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    /// Apply Hanning window and zero-pad to FFT size
    private func applyHanningWindow(samples: [Float], fftSize: Int) -> [Float] {
        var result = [Float](repeating: 0, count: fftSize)

        for i in 0..<samples.count {
            let window = Float(0.5 * (1 - cos(2 * Double.pi * Double(i) / Double(samples.count - 1))))
            result[i] = samples[i] * window
        }

        return result
    }

    /// Compute magnitude spectrum using Accelerate vDSP
    private func computeMagnitudeSpectrum(samples: inout [Float]) -> [Float]? {
        let n = samples.count
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Create split complex arrays
        var realp = [Float](repeating: 0, count: n / 2)
        var imagp = [Float](repeating: 0, count: n / 2)

        // Convert to split complex format
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

                    // Perform FFT
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }
        }

        // Compute magnitudes
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

    /// Find the peak bin in the HPS
    private func findPeak(hps: [Double], minBin: Int, maxBin: Int) -> (bin: Int, value: Double)? {
        var maxValue: Double = 0
        var maxBinIndex: Int = minBin

        for i in minBin..<maxBin {
            if hps[i] > maxValue {
                maxValue = hps[i]
                maxBinIndex = i
            }
        }

        guard maxValue > 0 else { return nil }

        return (maxBinIndex, maxValue)
    }

    /// Parabolic interpolation for sub-bin accuracy
    private func parabolicInterpolation(hps: [Double], bin: Int) -> Double {
        guard bin > 0 && bin < hps.count - 1 else {
            return Double(bin)
        }

        let alpha = log(hps[bin - 1] + 1e-10)
        let beta = log(hps[bin] + 1e-10)
        let gamma = log(hps[bin + 1] + 1e-10)

        let denominator = alpha - 2 * beta + gamma
        guard abs(denominator) > 1e-10 else {
            return Double(bin)
        }

        let delta = 0.5 * (alpha - gamma) / denominator

        return Double(bin) + delta
    }
}
