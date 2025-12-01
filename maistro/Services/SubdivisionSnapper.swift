//
//  SubdivisionSnapper.swift
//  maistro
//
//  Utilities for snapping raw notes to discrete subdivisions and
//  converting between raw and discrete note representations.

import Foundation

/// Configuration for subdivision snapping
struct SnapperConfig {
    /// Tempo in BPM
    let tempo: Double

    /// The note value that gets one beat (4 = quarter note, 8 = eighth note)
    let tempoSubdivision: Int

    /// The smallest subdivision to snap to (8 = eighth, 16 = sixteenth, etc.)
    let subdivisionResolution: Int

    /// Time signature for measure calculations
    let timeSignature: TimeSignature
}

/// Utility for snapping time values to discrete subdivisions
struct SubdivisionSnapper {
    let config: SnapperConfig

    init(config: SnapperConfig) {
        self.config = config
    }

    /// Duration of one beat at the tempo subdivision in milliseconds
    var beatDurationMs: Double {
        60000.0 / config.tempo
    }

    /// Duration of one subdivision in milliseconds
    var subdivisionDurationMs: Double {
        beatDurationMs * Double(config.tempoSubdivision) / Double(config.subdivisionResolution)
    }

    /// Number of subdivisions per measure
    var subdivisionsPerMeasure: Int {
        config.timeSignature.numerator * config.subdivisionResolution / config.timeSignature.denominator
    }

    /// Snap a duration in milliseconds to subdivision count
    /// - Parameters:
    ///   - durationMs: Duration in milliseconds
    ///   - allowZero: Whether to allow rounding to zero subdivisions
    /// - Returns: Number of subdivisions
    func snapToSubdivisions(durationMs: UInt64, allowZero: Bool) -> Int {
        let subdivisions = Int((Double(durationMs) / subdivisionDurationMs).rounded())
        if !allowZero && subdivisions == 0 {
            return 1
        }
        return subdivisions
    }

    /// Snap a start offset in milliseconds to subdivision position
    /// - Parameter offsetMs: Offset from passage start in milliseconds
    /// - Returns: Subdivision position (0-indexed from passage start)
    func snapStartOffset(offsetMs: UInt64) -> Int {
        Int((Double(offsetMs) / subdivisionDurationMs).rounded())
    }
}

/// Converts raw passages to discrete passages
struct RawToDiscreteConverter {
    let snapper: SubdivisionSnapper

    init(snapper: SubdivisionSnapper) {
        self.snapper = snapper
    }

    /// Convert a raw passage to a discrete passage
    /// - Parameters:
    ///   - rawPassage: The raw passage to convert
    ///   - measureCount: Expected number of measures
    ///   - noteName: The note name to use for all notes (rhythm practice uses a fixed pitch)
    /// - Returns: A discrete passage with notes snapped to subdivisions
    func convert(rawPassage: RawPassage, measureCount: Int, noteName: String) -> DiscretePassage {
        let subdivisionsPerMeasure = snapper.subdivisionsPerMeasure
        let resolution = snapper.config.subdivisionResolution

        // Initialize measures
        var measures: [DiscreteMeasure] = (0..<measureCount).map { _ in
            DiscreteMeasure(
                subdivisionDenominator: resolution,
                elements: []
            )
        }

        // Convert each note
        for rawNote in rawPassage.notes {
            let startSubdivision = snapper.snapStartOffset(offsetMs: rawNote.startOffsetMs)
            let totalDurationSubdivisions = snapper.snapToSubdivisions(
                durationMs: rawNote.note.durationMs,
                allowZero: false
            )

            var currentMeasureIndex = startSubdivision / subdivisionsPerMeasure
            var currentMeasurePosition = startSubdivision % subdivisionsPerMeasure
            var remainingSubdivisions = totalDurationSubdivisions

            // Process note across measure boundaries (creates tied notes)
            var isFirstPartOfNote = true
            while remainingSubdivisions > 0 && currentMeasureIndex < measureCount {
                // How many subdivisions can fit in this measure?
                let subdivisionsLeftInMeasure = subdivisionsPerMeasure - currentMeasurePosition
                let subdivisionsForThisMeasure = min(remainingSubdivisions, subdivisionsLeftInMeasure)

                // Compute durations for this portion of the note
                let noteDurations = computeNoteDurations(
                    startSubdivision: currentMeasurePosition,
                    totalSubdivisions: subdivisionsForThisMeasure,
                    resolution: resolution,
                    maxPosition: subdivisionsPerMeasure
                )

                let discreteNote = DiscreteNote(
                    noteName: noteName,
                    noteDurations: noteDurations
                )

                // Mark as tied from previous if this is a continuation across bar line
                let element = DiscreteMeasureElement(
                    element: .note(discreteNote),
                    startSubdivision: currentMeasurePosition,
                    tiedFromPrevious: !isFirstPartOfNote
                )

                measures[currentMeasureIndex] = DiscreteMeasure(
                    subdivisionDenominator: measures[currentMeasureIndex].subdivisionDenominator,
                    elements: measures[currentMeasureIndex].elements + [element]
                )

                // Move to next measure
                remainingSubdivisions -= subdivisionsForThisMeasure
                currentMeasureIndex += 1
                currentMeasurePosition = 0
                isFirstPartOfNote = false
            }
        }

        // Fill in rests for gaps
        measures = fillRests(measures: measures, measureCount: measureCount)

        return DiscretePassage(measures: measures)
    }

    /// Compute the best notation for a given subdivision duration
    /// - Parameters:
    ///   - startSubdivision: Starting position within the measure
    ///   - totalSubdivisions: Total duration in subdivisions
    ///   - resolution: Subdivision resolution (e.g., 8 for eighth notes)
    ///   - maxPosition: Maximum position (measure boundary) - durations won't extend past this
    private func computeNoteDurations(
        startSubdivision: Int,
        totalSubdivisions: Int,
        resolution: Int,
        maxPosition: Int
    ) -> [DenominatorDots] {
        var durations: [DenominatorDots] = []
        var remainingSubdivisions = totalSubdivisions
        var currentPosition = startSubdivision

        while remainingSubdivisions > 0 && currentPosition < maxPosition {
            // Don't allow durations to extend past the measure boundary
            let availableSubdivisions = min(remainingSubdivisions, maxPosition - currentPosition)
            let (duration, subdivisionCount) = findLargestFittingDuration(
                position: currentPosition,
                remaining: availableSubdivisions,
                resolution: resolution
            )
            durations.append(duration)
            remainingSubdivisions -= subdivisionCount
            currentPosition += subdivisionCount
        }

        return durations
    }

    /// Find the largest duration that fits at the current position
    private func findLargestFittingDuration(
        position: Int,
        remaining: Int,
        resolution: Int
    ) -> (DenominatorDots, Int) {
        // Try denominators from largest to smallest: 1 (whole), 2 (half), 4 (quarter), 8 (eighth), 16, 32
        let denominators = [1, 2, 4, 8, 16, 32]

        for denominator in denominators {
            let baseSubdivisions = resolution / denominator
            guard baseSubdivisions > 0 else { continue }

            // Check alignment: note must start at a position divisible by its subdivision count
            let alignment = baseSubdivisions
            guard position % alignment == 0 else { continue }

            // Try with dots
            if baseSubdivisions * 7 / 4 <= remaining && baseSubdivisions >= 4 && position % (baseSubdivisions * 2) == 0 {
                // Double dotted
                return (DenominatorDots(denominator: denominator, dots: 2), baseSubdivisions * 7 / 4)
            }
            if baseSubdivisions * 3 / 2 <= remaining && baseSubdivisions >= 2 && position % (baseSubdivisions) == 0 {
                // Single dotted
                return (DenominatorDots(denominator: denominator, dots: 1), baseSubdivisions * 3 / 2)
            }
            if baseSubdivisions <= remaining {
                // No dots
                return (DenominatorDots(denominator: denominator, dots: 0), baseSubdivisions)
            }
        }

        // Fallback to smallest note value
        let smallestDenominator = resolution
        return (DenominatorDots(denominator: smallestDenominator, dots: 0), 1)
    }

    /// Fill in rests for gaps between notes and at measure boundaries
    private func fillRests(measures: [DiscreteMeasure], measureCount: Int) -> [DiscreteMeasure] {
        let subdivisionsPerMeasure = snapper.subdivisionsPerMeasure
        let resolution = snapper.config.subdivisionResolution

        return measures.map { measure in
            var filledElements: [DiscreteMeasureElement] = []
            var currentPosition = 0

            // Sort elements by start position
            let sortedElements = measure.elements.sorted { $0.startSubdivision < $1.startSubdivision }

            for element in sortedElements {
                // Fill gap with rests
                if element.startSubdivision > currentPosition {
                    let restDurations = computeRestDurations(
                        startSubdivision: currentPosition,
                        endSubdivision: element.startSubdivision,
                        resolution: resolution
                    )
                    for (position, duration) in restDurations {
                        let rest = DiscreteRest(restDurations: [duration])
                        filledElements.append(DiscreteMeasureElement(
                            element: .rest(rest),
                            startSubdivision: position,
                            tiedFromPrevious: false
                        ))
                    }
                }

                filledElements.append(element)

                // Update current position
                switch element.element {
                case .note(let note):
                    currentPosition = element.startSubdivision + note.totalSubdivisionDuration(resolution: resolution)
                case .rest(let rest):
                    currentPosition = element.startSubdivision + rest.totalSubdivisionDuration(resolution: resolution)
                }
            }

            // Fill remaining space with rests
            if currentPosition < subdivisionsPerMeasure {
                let restDurations = computeRestDurations(
                    startSubdivision: currentPosition,
                    endSubdivision: subdivisionsPerMeasure,
                    resolution: resolution
                )
                for (position, duration) in restDurations {
                    let rest = DiscreteRest(restDurations: [duration])
                    filledElements.append(DiscreteMeasureElement(
                        element: .rest(rest),
                        startSubdivision: position,
                        tiedFromPrevious: false
                    ))
                }
            }

            return DiscreteMeasure(
                subdivisionDenominator: measure.subdivisionDenominator,
                elements: filledElements
            )
        }
    }

    /// Compute rest durations to fill a gap
    private func computeRestDurations(
        startSubdivision: Int,
        endSubdivision: Int,
        resolution: Int
    ) -> [(Int, DenominatorDots)] {
        var rests: [(Int, DenominatorDots)] = []
        var position = startSubdivision

        while position < endSubdivision {
            let remaining = endSubdivision - position
            let (duration, subdivisionCount) = findLargestFittingDuration(
                position: position,
                remaining: remaining,
                resolution: resolution
            )
            rests.append((position, duration))
            position += subdivisionCount
        }

        return rests
    }
}
