//
//  PassageGenerator.swift
//  maistro
//
//  Generates random rhythm passages for practice

import Foundation

class PassageGenerator {
    static let shared = PassageGenerator()

    private init() {}

    /// Generate a random passage with the given parameters
    func generatePassage(
        measureCount: Int,
        timeSignature: TimeSignature,
        smallestSubdivision: Int
    ) -> DiscretePassage {
        var measures: [DiscreteMeasure] = []

        for measureIndex in 0..<measureCount {
            let measure = generateMeasure(
                measureIndex: measureIndex,
                totalMeasures: measureCount,
                timeSignature: timeSignature,
                smallestSubdivision: smallestSubdivision
            )
            measures.append(measure)
        }

        return DiscretePassage(measures: measures)
    }

    private func generateMeasure(
        measureIndex: Int,
        totalMeasures: Int,
        timeSignature: TimeSignature,
        smallestSubdivision: Int
    ) -> DiscreteMeasure {
        let subdivisionsInMeasure = timeSignature.subdivisionsPerMeasure(smallestSubdivision: smallestSubdivision)
        var elements: [DiscreteMeasureElement] = []
        var allocatedSubdivisions = 0

        while allocatedSubdivisions < subdivisionsInMeasure {
            let remainingSubdivisions = subdivisionsInMeasure - allocatedSubdivisions
            let roll = Int.random(in: 1...remainingSubdivisions)

            // Coin flip for rest vs note
            let isRest = Bool.random()

            // Don't start or end the entire passage with a rest
            let isFirstBeatOfFirstMeasure = measureIndex == 0 && allocatedSubdivisions == 0
            let isLastBeatOfLastMeasure = measureIndex == totalMeasures - 1 &&
                                          allocatedSubdivisions + roll == subdivisionsInMeasure

            let shouldRest = isRest && !isFirstBeatOfFirstMeasure && !isLastBeatOfLastMeasure

            if shouldRest {
                let restDurations = convertSubdivisionsToNoteDurations(
                    subdivisions: roll,
                    startSubdivision: allocatedSubdivisions,
                    smallestSubdivision: smallestSubdivision
                )
                let rest = DiscreteRest(restDurations: restDurations)
                elements.append(DiscreteMeasureElement(
                    element: .rest(rest),
                    startSubdivision: allocatedSubdivisions,
                    tiedFromPrevious: false
                ))
            } else {
                let noteDurations = convertSubdivisionsToNoteDurations(
                    subdivisions: roll,
                    startSubdivision: allocatedSubdivisions,
                    smallestSubdivision: smallestSubdivision
                )
                // Use a fixed pitch for rhythm practice (B4 is on the middle line)
                let note = DiscreteNote(noteName: "B4", noteDurations: noteDurations)
                elements.append(DiscreteMeasureElement(
                    element: .note(note),
                    startSubdivision: allocatedSubdivisions,
                    tiedFromPrevious: false
                ))
            }

            allocatedSubdivisions += roll
        }

        // If the entire measure is rests, consolidate into a single whole rest
        let allRests = elements.allSatisfy { element in
            if case .rest = element.element { return true }
            return false
        }

        if allRests && !elements.isEmpty {
            let wholeRestDurations = convertSubdivisionsToNoteDurations(
                subdivisions: subdivisionsInMeasure,
                startSubdivision: 0,
                smallestSubdivision: smallestSubdivision
            )
            let wholeRest = DiscreteRest(restDurations: wholeRestDurations)
            return DiscreteMeasure(
                subdivisionDenominator: smallestSubdivision,
                elements: [DiscreteMeasureElement(
                    element: .rest(wholeRest),
                    startSubdivision: 0,
                    tiedFromPrevious: false
                )]
            )
        }

        return DiscreteMeasure(
            subdivisionDenominator: smallestSubdivision,
            elements: elements
        )
    }

    /// Convert a number of subdivisions into note/rest durations
    /// This handles proper rhythmic notation using a greedy algorithm that finds
    /// the largest note value that fits at each position while respecting subdivision boundaries.
    /// Each note value stays within its own "grid cell" (e.g., half notes don't cross half-measure
    /// boundaries, quarter notes don't cross beat boundaries).
    /// - Parameters:
    ///   - subdivisions: Number of subdivisions to convert
    ///   - startSubdivision: The starting position within the measure
    ///   - smallestSubdivision: The resolution (e.g., 8 for eighths, 16 for sixteenths, 32 for thirty-seconds)
    private func convertSubdivisionsToNoteDurations(
        subdivisions: Int,
        startSubdivision: Int,
        smallestSubdivision: Int
    ) -> [DenominatorDots] {
        var result: [DenominatorDots] = []
        var remaining = subdivisions
        var currentPosition = startSubdivision

        while remaining > 0 {
            let (duration, subdivisionCount) = findLargestFittingDuration(
                remaining: remaining,
                position: currentPosition,
                smallestSubdivision: smallestSubdivision
            )
            result.append(duration)
            remaining -= subdivisionCount
            currentPosition += subdivisionCount
        }

        return result
    }

    /// Find the largest note duration that fits at the given position
    /// Returns the duration and how many subdivisions it consumes
    /// - Parameters:
    ///   - remaining: Number of subdivisions remaining to fill
    ///   - position: Current position within the measure
    ///   - smallestSubdivision: The resolution
    private func findLargestFittingDuration(
        remaining: Int,
        position: Int,
        smallestSubdivision: Int
    ) -> (DenominatorDots, Int) {
        // Build note values dynamically, filtering out those that can't be represented
        // at the current resolution.
        //
        // For dots to be valid:
        // - Single dot adds 1/2 of base duration, so base must be >= 2 subdivisions
        // - Double dot adds 1/2 + 1/4 of base, so base must be >= 4 subdivisions
        //
        // Base subdivisions for a note = smallestSubdivision / denominator

        var noteValues: [(subdivisions: Int, denominator: Int, dots: Int, alignment: Int)] = []

        // Denominators from largest note to smallest
        let denominators = [1, 2, 4, 8, 16, 32]

        for denom in denominators {
            let baseSubdivisions = smallestSubdivision / denom
            guard baseSubdivisions >= 1 else { continue }

            let alignment = baseSubdivisions

            // Double-dotted: requires base >= 4 subdivisions (so 1/4 of base >= 1)
            if baseSubdivisions >= 4 {
                let doubleDottedSubdivisions = baseSubdivisions + baseSubdivisions / 2 + baseSubdivisions / 4
                noteValues.append((doubleDottedSubdivisions, denom, 2, alignment))
            }

            // Single-dotted: requires base >= 2 subdivisions (so 1/2 of base >= 1)
            if baseSubdivisions >= 2 {
                let dottedSubdivisions = baseSubdivisions + baseSubdivisions / 2
                noteValues.append((dottedSubdivisions, denom, 1, alignment))
            }

            // Undotted: always valid if base >= 1
            noteValues.append((baseSubdivisions, denom, 0, alignment))
        }

        // Sort by subdivisions descending (largest first)
        noteValues.sort { $0.subdivisions > $1.subdivisions }

        for noteValue in noteValues {
            let subdivisionCount = noteValue.subdivisions
            let alignment = noteValue.alignment

            // Check if this note fits and is properly aligned
            guard subdivisionCount <= remaining && position % alignment == 0 else {
                continue
            }

            // Check if this duration would cross its own subdivision boundary.
            // Each note value has boundaries at multiples of its alignment:
            // - Half notes: boundaries every half-measure
            // - Quarter notes: boundaries every beat
            // - Eighth notes: boundaries every half-beat
            // A note starting at position P with alignment A has its next boundary at P + A.
            // If the note's duration exceeds its alignment, it crosses into the next cell.
            let crossesOwnBoundary = subdivisionCount > alignment

            if !crossesOwnBoundary {
                return (
                    DenominatorDots(denominator: noteValue.denominator, dots: noteValue.dots),
                    subdivisionCount
                )
            }
        }

        // Fallback: use the smallest subdivision unit
        return (
            DenominatorDots(denominator: smallestSubdivision, dots: 0),
            1
        )
    }
}
