//
//  PassageGeneratorTests.swift
//  maistroTests
//
//  Tests for PassageGenerator rhythm passage generation
//

import Testing
@testable import maistro

struct PassageGeneratorTests {

    let generator = PassageGenerator.shared

    @Test func sandbox() {
        let passage = generator.generatePassage(measureCount: 1, timeSignature: TimeSignature(4, 4), smallestSubdivision: 8)
        print(passage)
    }
    // MARK: - Basic Passage Generation

    @Test func generatesCorrectNumberOfMeasures() {
        let timeSignature = TimeSignature(4, 4)

        for measureCount in [1, 2, 4, 8] {
            let passage = generator.generatePassage(
                measureCount: measureCount,
                timeSignature: timeSignature,
                smallestSubdivision: 8
            )
            #expect(passage.measures.count == measureCount)
        }
    }

    @Test func eachMeasureHasCorrectTotalDuration() {
        let testCases: [(TimeSignature, Int)] = [
            (TimeSignature(4, 4), 8),  // 4/4 = 8 eighth notes
            (TimeSignature(3, 4), 6),  // 3/4 = 6 eighth notes
            (TimeSignature(6, 8), 6),  // 6/8 = 6 eighth notes
            (TimeSignature(2, 4), 4),  // 2/4 = 4 eighth notes
            (TimeSignature(5, 4), 10), // 5/4 = 10 eighth notes
        ]

        for (timeSignature, expectedSubdivisions) in testCases {
            let passage = generator.generatePassage(
                measureCount: 4,
                timeSignature: timeSignature,
                smallestSubdivision: 8
            )

            for measure in passage.measures {
                let totalDuration = measure.elements.reduce(0) { total, element in
                    switch element.element {
                    case .note(let note):
                        return total + note.totalSubdivisionDuration()
                    case .rest(let rest):
                        return total + rest.totalSubdivisionDuration()
                    }
                }
                #expect(totalDuration == expectedSubdivisions,
                       "Measure duration \(totalDuration) != expected \(expectedSubdivisions) for \(timeSignature.displayString)")
            }
        }
    }

    @Test func measuresHaveAtLeastOneElement() {
        let passage = generator.generatePassage(
            measureCount: 10,
            timeSignature: TimeSignature(4, 4),
            smallestSubdivision: 8
        )

        for measure in passage.measures {
            #expect(!measure.elements.isEmpty)
        }
    }

    // MARK: - Rest Placement Rules

    @Test func firstBeatOfFirstMeasureIsNotARest() {
        // Run multiple times since generation is random
        for _ in 0..<20 {
            let passage = generator.generatePassage(
                measureCount: 4,
                timeSignature: TimeSignature(4, 4),
                smallestSubdivision: 8
            )

            guard let firstElement = passage.measures.first?.elements.first else {
                Issue.record("First measure has no elements")
                return
            }

            if case .rest = firstElement.element {
                Issue.record("First element of passage should not be a rest")
            }
        }
    }

    @Test func lastBeatOfLastMeasureIsNotARest() {
        // Run multiple times since generation is random
        for _ in 0..<20 {
            let passage = generator.generatePassage(
                measureCount: 4,
                timeSignature: TimeSignature(4, 4),
                smallestSubdivision: 8
            )

            guard let lastElement = passage.measures.last?.elements.last else {
                Issue.record("Last measure has no elements")
                return
            }

            if case .rest = lastElement.element {
                Issue.record("Last element of passage should not be a rest")
            }
        }
    }

    // MARK: - Note Properties

    @Test func allNotesUseFixedPitch() {
        let passage = generator.generatePassage(
            measureCount: 4,
            timeSignature: TimeSignature(4, 4),
            smallestSubdivision: 8
        )

        for measure in passage.measures {
            for element in measure.elements {
                if case .note(let note) = element.element {
                    #expect(note.noteName == "B4", "Expected B4, got \(note.noteName)")
                }
            }
        }
    }

    // MARK: - Subdivision Denominator

    @Test func measuresHaveCorrectSubdivisionDenominator() {
        let passage = generator.generatePassage(
            measureCount: 4,
            timeSignature: TimeSignature(4, 4),
            smallestSubdivision: 8
        )

        for measure in passage.measures {
            #expect(measure.subdivisionDenominator == 8)
        }
    }

    // MARK: - Start Subdivision Tracking

    @Test func elementsHaveCorrectStartSubdivisions() {
        let passage = generator.generatePassage(
            measureCount: 4,
            timeSignature: TimeSignature(4, 4),
            smallestSubdivision: 8
        )

        for measure in passage.measures {
            var expectedStart = 0
            for element in measure.elements {
                #expect(element.startSubdivision == expectedStart,
                       "Element should start at \(expectedStart), but starts at \(element.startSubdivision)")

                let duration: Int
                switch element.element {
                case .note(let note):
                    duration = note.totalSubdivisionDuration()
                case .rest(let rest):
                    duration = rest.totalSubdivisionDuration()
                }
                expectedStart += duration
            }
        }
    }

    // MARK: - Duration Conversion Tests

    @Test func durationConversionProducesValidDenominators() {
        // Generate many passages to test various duration conversions
        for _ in 0..<10 {
            let passage = generator.generatePassage(
                measureCount: 8,
                timeSignature: TimeSignature(4, 4),
                smallestSubdivision: 8
            )

            let validDenominators = [1, 2, 4, 8, 16]

            for measure in passage.measures {
                for element in measure.elements {
                    let durations: [DenominatorDots]
                    switch element.element {
                    case .note(let note):
                        durations = note.noteDurations
                    case .rest(let rest):
                        durations = rest.restDurations
                    }

                    for duration in durations {
                        #expect(validDenominators.contains(duration.denominator),
                               "Invalid denominator: \(duration.denominator)")
                        #expect(duration.dots >= 0 && duration.dots <= 2,
                               "Invalid dot count: \(duration.dots)")
                    }
                }
            }
        }
    }
}

// MARK: - DenominatorDots Tests

struct DenominatorDotsTests {

    @Test func subdivisionDurationCalculation() {
        // Whole note = 8 subdivisions
        #expect(DenominatorDots(denominator: 1, dots: 0).subdivisionDuration() == 8)

        // Half note = 4 subdivisions
        #expect(DenominatorDots(denominator: 2, dots: 0).subdivisionDuration() == 4)

        // Quarter note = 2 subdivisions
        #expect(DenominatorDots(denominator: 4, dots: 0).subdivisionDuration() == 2)

        // Eighth note = 1 subdivision
        #expect(DenominatorDots(denominator: 8, dots: 0).subdivisionDuration() == 1)
    }

    @Test func dottedNoteDurations() {
        // Dotted half = 6 subdivisions (4 + 2)
        #expect(DenominatorDots(denominator: 2, dots: 1).subdivisionDuration() == 6)

        // Dotted quarter = 3 subdivisions (2 + 1)
        #expect(DenominatorDots(denominator: 4, dots: 1).subdivisionDuration() == 3)

        // Double-dotted half = 7 subdivisions (4 + 2 + 1)
        #expect(DenominatorDots(denominator: 2, dots: 2).subdivisionDuration() == 7)
    }

    @Test func vexFlowDurationString() {
        #expect(DenominatorDots(denominator: 4, dots: 0).vexFlowDuration == "4")
        #expect(DenominatorDots(denominator: 4, dots: 1).vexFlowDuration == "4.")
        #expect(DenominatorDots(denominator: 2, dots: 2).vexFlowDuration == "2..")
    }
}

// MARK: - TimeSignature Tests

struct TimeSignatureTests {

    @Test func subdivisionsPerMeasure() {
        #expect(TimeSignature(4, 4).subdivisionsPerMeasure == 8)
        #expect(TimeSignature(3, 4).subdivisionsPerMeasure == 6)
        #expect(TimeSignature(6, 8).subdivisionsPerMeasure == 6)
        #expect(TimeSignature(2, 4).subdivisionsPerMeasure == 4)
        #expect(TimeSignature(2, 2).subdivisionsPerMeasure == 8)
        #expect(TimeSignature(5, 4).subdivisionsPerMeasure == 10)
    }

    @Test func displayString() {
        #expect(TimeSignature(4, 4).displayString == "4/4")
        #expect(TimeSignature(6, 8).displayString == "6/8")
    }

    @Test func stringInitialization() {
        let ts = TimeSignature(string: "3/4")
        #expect(ts != nil)
        #expect(ts?.numerator == 3)
        #expect(ts?.denominator == 4)
    }

    @Test func invalidStringReturnsNil() {
        #expect(TimeSignature(string: "invalid") == nil)
        #expect(TimeSignature(string: "4") == nil)
        #expect(TimeSignature(string: "") == nil)
    }
}

// MARK: - DiscreteNote Tests

struct DiscreteNoteTests {

    @Test func totalSubdivisionDuration() {
        // Single quarter note = 2 subdivisions
        let singleNote = DiscreteNote(
            noteName: "B4",
            noteDurations: [DenominatorDots(denominator: 4, dots: 0)]
        )
        #expect(singleNote.totalSubdivisionDuration() == 2)

        // Two eighths = 2 subdivisions
        let twoEighths = DiscreteNote(
            noteName: "B4",
            noteDurations: [
                DenominatorDots(denominator: 8, dots: 0),
                DenominatorDots(denominator: 8, dots: 0)
            ]
        )
        #expect(twoEighths.totalSubdivisionDuration() == 2)
    }
}

// MARK: - VexFlow Conversion Tests

struct VexFlowConversionTests {

    @Test func toVexFlowNotation() {
        let note = DiscreteNote(
            noteName: "B4",
            noteDurations: [DenominatorDots(denominator: 4, dots: 0)]
        )
        let element = DiscreteMeasureElement(
            element: .note(note),
            startSubdivision: 0
        )
        let measure = DiscreteMeasure(subdivisionDenominator: 8, elements: [element])
        let passage = DiscretePassage(measures: [measure])

        let notation = passage.toVexFlowNotation()
        #expect(notation.count == 1)
        #expect(notation[0] == ["B4/4"])
    }

    @Test func restNotation() {
        let rest = DiscreteRest(
            restDurations: [DenominatorDots(denominator: 4, dots: 0)]
        )
        let element = DiscreteMeasureElement(
            element: .rest(rest),
            startSubdivision: 0
        )
        let measure = DiscreteMeasure(subdivisionDenominator: 8, elements: [element])
        let passage = DiscretePassage(measures: [measure])

        let notation = passage.toVexFlowNotation()
        #expect(notation[0] == ["B4/4/r"])
    }
}
