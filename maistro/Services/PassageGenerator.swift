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
        let subdivisionsInMeasure = timeSignature.subdivisionsPerMeasure
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
                    startSubdivision: allocatedSubdivisions
                )
                let rest = DiscreteRest(restDurations: restDurations)
                elements.append(DiscreteMeasureElement(
                    element: .rest(rest),
                    startSubdivision: allocatedSubdivisions
                ))
            } else {
                let noteDurations = convertSubdivisionsToNoteDurations(
                    subdivisions: roll,
                    startSubdivision: allocatedSubdivisions
                )
                // Use a fixed pitch for rhythm practice (B4 is on the middle line)
                let note = DiscreteNote(noteName: "B4", noteDurations: noteDurations)
                elements.append(DiscreteMeasureElement(
                    element: .note(note),
                    startSubdivision: allocatedSubdivisions
                ))
            }

            allocatedSubdivisions += roll
        }

        return DiscreteMeasure(
            subdivisionDenominator: smallestSubdivision,
            elements: elements
        )
    }

    /// Convert a number of subdivisions into note/rest durations
    /// This handles proper rhythmic notation (e.g., 3 eighths becomes dotted quarter)
    private func convertSubdivisionsToNoteDurations(
        subdivisions: Int,
        startSubdivision: Int
    ) -> [DenominatorDots] {
        // This is a simplified version - for complex rhythms, you'd need more logic
        // to handle tied notes across beat boundaries

        switch subdivisions {
        case 1:
            return [DenominatorDots(denominator: 8, dots: 0)]
        case 2:
            if startSubdivision % 2 == 0 {
                return [DenominatorDots(denominator: 4, dots: 0)]
            } else {
                return [
                    DenominatorDots(denominator: 8, dots: 0),
                    DenominatorDots(denominator: 8, dots: 0)
                ]
            }
        case 3:
            if startSubdivision % 2 == 0 {
                return [DenominatorDots(denominator: 4, dots: 1)]
            } else {
                return [
                    DenominatorDots(denominator: 8, dots: 0),
                    DenominatorDots(denominator: 4, dots: 0)
                ]
            }
        case 4:
            if startSubdivision % 4 == 0 {
                return [DenominatorDots(denominator: 2, dots: 0)]
            } else if startSubdivision % 4 == 2 {
                return [
                    DenominatorDots(denominator: 4, dots: 0),
                    DenominatorDots(denominator: 4, dots: 0)
                ]
            } else {
                return [
                    DenominatorDots(denominator: 8, dots: 0),
                    DenominatorDots(denominator: 4, dots: 1)
                ]
            }
        case 5:
            if startSubdivision % 2 == 0 {
                return [
                    DenominatorDots(denominator: 2, dots: 0),
                    DenominatorDots(denominator: 8, dots: 0)
                ]
            } else {
                return [
                    DenominatorDots(denominator: 8, dots: 0),
                    DenominatorDots(denominator: 2, dots: 0)
                ]
            }
        case 6:
            if startSubdivision == 0 {
                return [
                    DenominatorDots(denominator: 2, dots: 1)
                ]
            } else if startSubdivision == 2 {
                return [
                    DenominatorDots(denominator: 4, dots: 0),
                    DenominatorDots(denominator: 2, dots: 0)
                ]
            } else {
                return [
                    DenominatorDots(denominator: 8, dots: 0),
                    DenominatorDots(denominator: 2, dots: 0),
                    DenominatorDots(denominator: 8, dots: 0)
                ]
            }
        case 7:
            if startSubdivision == 0 {
                return [DenominatorDots(denominator: 2, dots: 2)]
            } else {
                return [
                    DenominatorDots(denominator: 8, dots: 0),
                    DenominatorDots(denominator: 2, dots: 1)
                ]
            }
        case 8:
            return [DenominatorDots(denominator: 1, dots: 0)]
        default:
            // Fallback for larger values - just use whole notes and quarters
            var result: [DenominatorDots] = []
            var remaining = subdivisions
            while remaining >= 8 {
                result.append(DenominatorDots(denominator: 1, dots: 0))
                remaining -= 8
            }
            if remaining > 0 {
                result.append(contentsOf: convertSubdivisionsToNoteDurations(
                    subdivisions: remaining,
                    startSubdivision: startSubdivision
                ))
            }
            return result
        }
    }
}
