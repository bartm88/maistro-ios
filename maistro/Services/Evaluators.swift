//
//  Evaluators.swift
//  maistro
//
//  Evaluators for assessing the accuracy of played passages.
//  These operate on raw notes to provide fine-grained timing feedback.

import Foundation

/// Context for evaluation
struct EvaluationContext {
    let tempo: Double
    let tempoSubdivision: Int
    let subdivisionResolution: Int

    /// Duration of one subdivision in milliseconds
    var subdivisionDurationMs: Double {
        let beatDurationMs = 60000.0 / tempo
        return beatDurationMs * Double(tempoSubdivision) / Double(subdivisionResolution)
    }
}

/// Critique for a specific note
enum NoteCritique: Equatable {
    case slightlyEarly
    case slightlyLate
    case moderatelyEarly
    case moderatelyLate
    case severelyEarly
    case severelyLate

    var description: String {
        switch self {
        case .slightlyEarly: return "Slightly early"
        case .slightlyLate: return "Slightly late"
        case .moderatelyEarly: return "Moderately early"
        case .moderatelyLate: return "Moderately late"
        case .severelyEarly: return "Severely early"
        case .severelyLate: return "Severely late"
        }
    }
}

/// Result of evaluating a single aspect of performance
struct VectorEvaluation {
    /// Score from 0.0 to 1.0
    let score: Double

    /// Critiques for individual notes (indexed by note position)
    let noteCritiques: [Int: NoteCritique]

    /// Overall passage-level critique messages
    let passageCritiques: Set<String>
}

/// Evaluator protocol for different aspects of performance
protocol Evaluator {
    func evaluate(
        expected: RawPassage,
        actual: RawPassage,
        context: EvaluationContext
    ) -> VectorEvaluation
}

// StartTimeEvaluator moved to Evaluators/StartTimeEvaluator.swift

/// Combined evaluation result for all aspects
struct EvaluationResult {
    let rhythmEvaluation: VectorEvaluation

    /// Overall rhythm score (0.0 to 1.0)
    var rhythmScore: Double {
        rhythmEvaluation.score
    }
}

/// Evaluates a played passage against an expected passage
struct PassageEvaluator {
    let context: EvaluationContext
    let startTimeEvaluator: StartTimeEvaluator

    init(context: EvaluationContext) {
        self.context = context
        self.startTimeEvaluator = StartTimeEvaluator(
            thresholds: .default(),
            chordToleranceMs: 50.0
        )
    }

    init(
        context: EvaluationContext,
        startTimeThresholds: StartTimeEvaluator.Thresholds,
        chordToleranceMs: Double
    ) {
        self.context = context
        self.startTimeEvaluator = StartTimeEvaluator(
            thresholds: startTimeThresholds,
            chordToleranceMs: chordToleranceMs
        )
    }

    /// Convert a discrete passage to a raw passage for evaluation
    /// This generates expected start times based on the subdivision positions
    func discreteToRawPassage(
        discretePassage: DiscretePassage,
        timeSignature: TimeSignature
    ) -> RawPassage {
        let subdivisionsPerMeasure = timeSignature.subdivisionsPerMeasure(
            smallestSubdivision: context.subdivisionResolution
        )
        let subdivisionDurationMs = context.subdivisionDurationMs

        var notes: [RawPassageNote] = []

        for (measureIndex, measure) in discretePassage.measures.enumerated() {
            for element in measure.elements {
                switch element.element {
                case .note(let note):
                    let passageSubdivisionStart = measureIndex * subdivisionsPerMeasure + element.startSubdivision
                    let startOffsetMs = UInt64(Double(passageSubdivisionStart) * subdivisionDurationMs)
                    let durationSubdivisions = note.totalSubdivisionDuration(resolution: context.subdivisionResolution)
                    let durationMs = UInt64(Double(durationSubdivisions) * subdivisionDurationMs)

                    // Use a fixed pitch for rhythm evaluation
                    let rawNote = RawNote(pitchDeciHz: 4939, durationMs: durationMs)
                    notes.append(RawPassageNote(note: rawNote, startOffsetMs: startOffsetMs))
                case .rest:
                    break // Rests don't produce notes
                }
            }
        }

        return RawPassage(notes: notes)
    }

    /// Evaluate a played passage against an expected discrete passage
    func evaluate(
        expected: DiscretePassage,
        actual: RawPassage,
        timeSignature: TimeSignature
    ) -> EvaluationResult {
        let expectedRaw = discreteToRawPassage(
            discretePassage: expected,
            timeSignature: timeSignature
        )

        let rhythmEvaluation = startTimeEvaluator.evaluate(
            expected: expectedRaw,
            actual: actual,
            context: context
        )

        return EvaluationResult(rhythmEvaluation: rhythmEvaluation)
    }
}
