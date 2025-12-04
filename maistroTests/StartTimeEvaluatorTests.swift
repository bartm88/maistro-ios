//
//  StartTimeEvaluatorTests.swift
//  maistroTests
//
//  Tests for the StartTimeEvaluator, particularly for chord rhythm evaluation.
//

import Testing
@testable import maistro

struct StartTimeEvaluatorTests {

    // MARK: - Helper Functions

    func createContext(tempo: Double = 120.0) -> EvaluationContext {
        EvaluationContext(
            tempo: tempo,
            tempoSubdivision: 1,
            subdivisionResolution: 4
        )
    }

    func createEvaluator(chordToleranceMs: Double = 50.0) -> StartTimeEvaluator {
        StartTimeEvaluator(
            thresholds: .default(),
            chordToleranceMs: chordToleranceMs
        )
    }

    func createRawNote(startOffsetMs: UInt64, durationMs: UInt64 = 500) -> RawPassageNote {
        RawPassageNote(
            note: RawNote(pitchDeciHz: 4939, durationMs: durationMs),
            startOffsetMs: startOffsetMs
        )
    }

    // MARK: - Single Note Tests

    @Test func testSingleNoteOnTime() async throws {
        let context = createContext()
        let evaluator = createEvaluator()

        let expected = RawPassage(notes: [createRawNote(startOffsetMs: 0)])
        let actual = RawPassage(notes: [createRawNote(startOffsetMs: 0)])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        #expect(result.score == 1.0)
        #expect(result.noteCritiques.isEmpty)
        #expect(result.passageCritiques.isEmpty)
    }

    @Test func testSingleNoteSlightlyLate() async throws {
        let context = createContext(tempo: 120.0)
        let evaluator = createEvaluator()

        // At 120 BPM, one beat = 500ms, subdivision (1/4) = 125ms
        // 0.7 * 125ms = 87.5ms is between 0.5 and 1.0 subdivisions
        let expected = RawPassage(notes: [createRawNote(startOffsetMs: 0)])
        let actual = RawPassage(notes: [createRawNote(startOffsetMs: 88)])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        #expect(result.score < 1.0)
        #expect(result.noteCritiques[0] == .slightlyLate)
    }

    // MARK: - Chord Tests

    @Test func testChordOnTime() async throws {
        let context = createContext()
        let evaluator = createEvaluator()

        // Expected: 3-note chord at time 0
        let expected = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0)
        ])

        // Actual: 3-note chord at time 0 (within tolerance)
        let actual = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 5),
            createRawNote(startOffsetMs: 10)
        ])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        // Should get perfect score since all notes are within chord tolerance
        #expect(result.score == 1.0)
        #expect(result.noteCritiques.isEmpty)
        #expect(result.passageCritiques.isEmpty)
    }

    @Test func testChordSlightlyLate() async throws {
        let context = createContext(tempo: 120.0)
        let evaluator = createEvaluator()

        // At 120 BPM, one beat = 500ms, subdivision (1/4) = 125ms
        // 0.7 * 125ms = 87.5ms is between 0.5 and 1.0 subdivisions

        // Expected: 3-note chord at time 0
        let expected = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0)
        ])

        // Actual: 3-note chord at time ~88 (all slightly late together)
        let actual = RawPassage(notes: [
            createRawNote(startOffsetMs: 85),
            createRawNote(startOffsetMs: 88),
            createRawNote(startOffsetMs: 90)
        ])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        // Should penalize once for the chord being late, not once per note
        #expect(result.score < 1.0)
        #expect(result.score > 0.6) // Should have slight penalty (0.2), so score ~0.8

        // All notes in the chord should have the same critique
        #expect(result.noteCritiques[0] == .slightlyLate)
        #expect(result.noteCritiques[1] == .slightlyLate)
        #expect(result.noteCritiques[2] == .slightlyLate)
    }

    @Test func testMultipleChords() async throws {
        let context = createContext()
        let evaluator = createEvaluator()

        // Expected: Two 2-note chords at times 0 and 500
        let expected = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 500),
            createRawNote(startOffsetMs: 500)
        ])

        // Actual: Two 2-note chords at times ~0 and ~500 (within tolerance)
        let actual = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 10),
            createRawNote(startOffsetMs: 495),
            createRawNote(startOffsetMs: 505)
        ])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        // Should get perfect score since both chords are within tolerance
        #expect(result.score == 1.0)
        #expect(result.noteCritiques.isEmpty)
        #expect(result.passageCritiques.isEmpty)
    }

    @Test func testRhythmSequenceWithChordsAndSingleNotes() async throws {
        let context = createContext()
        let evaluator = createEvaluator()

        // Expected: Single note, chord, single note, chord
        let expected = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),      // Single note
            createRawNote(startOffsetMs: 250),    // Chord
            createRawNote(startOffsetMs: 250),
            createRawNote(startOffsetMs: 500),    // Single note
            createRawNote(startOffsetMs: 750),    // Chord
            createRawNote(startOffsetMs: 750)
        ])

        // Actual: Same rhythm (within tolerance)
        let actual = RawPassage(notes: [
            createRawNote(startOffsetMs: 5),      // Single note
            createRawNote(startOffsetMs: 245),    // Chord
            createRawNote(startOffsetMs: 255),
            createRawNote(startOffsetMs: 505),    // Single note
            createRawNote(startOffsetMs: 745),    // Chord
            createRawNote(startOffsetMs: 755)
        ])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        // Should get perfect score
        #expect(result.score == 1.0)
        #expect(result.noteCritiques.isEmpty)
        #expect(result.passageCritiques.isEmpty)
    }

    @Test func testChordToleranceEdgeCase() async throws {
        let context = createContext()
        let evaluator = createEvaluator(chordToleranceMs: 50.0)

        // Expected: Single chord
        let expected = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0)
        ])

        // Actual: Two notes just outside chord tolerance (should be treated as separate entities)
        let actual = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 51)
        ])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        // Should have penalty for having 2 rhythm entities instead of 1
        #expect(result.score < 1.0)
        #expect(result.passageCritiques.contains("Extra notes"))
    }

    @Test func testEmptyPassage() async throws {
        let context = createContext()
        let evaluator = createEvaluator()

        let expected = RawPassage(notes: [])
        let actual = RawPassage(notes: [])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        #expect(result.score == 1.0)
    }

    @Test func testMissedChord() async throws {
        let context = createContext()
        let evaluator = createEvaluator()

        // Expected: Two chords
        let expected = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 500),
            createRawNote(startOffsetMs: 500)
        ])

        // Actual: Only one chord
        let actual = RawPassage(notes: [
            createRawNote(startOffsetMs: 0),
            createRawNote(startOffsetMs: 10)
        ])

        let result = evaluator.evaluate(expected: expected, actual: actual, context: context)

        #expect(result.score < 1.0)
        #expect(result.passageCritiques.contains("Missed notes"))
    }
}
