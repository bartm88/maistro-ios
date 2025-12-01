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

/// Evaluates the timing accuracy of note start times
struct StartTimeEvaluator: Evaluator {
    /// Thresholds as fractions of a subdivision
    /// - Within 0.5 subdivisions: no penalty
    /// - 0.5 to 1.0 subdivisions: slight penalty (0.2)
    /// - 1.0 to 2.0 subdivisions: moderate penalty (0.5)
    /// - Beyond 2.0 subdivisions: severe penalty (1.0)
    struct Thresholds {
        let noPenaltyFraction: Double
        let slightPenaltyFraction: Double
        let moderatePenaltyFraction: Double

        let slightPenalty: Double
        let moderatePenalty: Double
        let severePenalty: Double

        static func `default`() -> Thresholds {
            Thresholds(
                noPenaltyFraction: 0.5,
                slightPenaltyFraction: 1.0,
                moderatePenaltyFraction: 2.0,
                slightPenalty: 0.2,
                moderatePenalty: 0.5,
                severePenalty: 1.0
            )
        }
    }

    let thresholds: Thresholds

    init(thresholds: Thresholds) {
        self.thresholds = thresholds
    }

    func evaluate(
        expected: RawPassage,
        actual: RawPassage,
        context: EvaluationContext
    ) -> VectorEvaluation {
        var passageCritiques: Set<String> = []
        var noteCritiques: [Int: NoteCritique] = [:]
        var score = 0.0

        // Penalize for wrong number of notes
        var measurePenalty = 1.0
        if actual.notes.count < expected.notes.count {
            passageCritiques.insert("Missed notes")
            measurePenalty = Double(actual.notes.count) / Double(expected.notes.count)
        } else if actual.notes.count > expected.notes.count {
            passageCritiques.insert("Extra notes")
            measurePenalty = Double(expected.notes.count) / Double(actual.notes.count)
        }

        guard !expected.notes.isEmpty else {
            return VectorEvaluation(
                score: actual.notes.isEmpty ? 1.0 : 0.0,
                noteCritiques: [:],
                passageCritiques: passageCritiques
            )
        }

        let scorePerNote = 1.0 / Double(expected.notes.count)
        let subdivisionDurationMs = context.subdivisionDurationMs

        for (index, expectedNote) in expected.notes.enumerated() {
            var notePenalty = 0.0

            if index < actual.notes.count {
                let actualNote = actual.notes[index]
                let distance = abs(Int64(actualNote.startOffsetMs) - Int64(expectedNote.startOffsetMs))
                let distanceDouble = Double(distance)

                let isEarly = actualNote.startOffsetMs < expectedNote.startOffsetMs

                // Determine penalty based on thresholds
                if distanceDouble < subdivisionDurationMs * thresholds.noPenaltyFraction {
                    // Within tolerance, no penalty
                    notePenalty = 0.0
                } else if distanceDouble < subdivisionDurationMs * thresholds.slightPenaltyFraction {
                    // Slight penalty
                    notePenalty = thresholds.slightPenalty
                    noteCritiques[index] = isEarly ? .slightlyEarly : .slightlyLate
                } else if distanceDouble < subdivisionDurationMs * thresholds.moderatePenaltyFraction {
                    // Moderate penalty
                    notePenalty = thresholds.moderatePenalty
                    noteCritiques[index] = isEarly ? .moderatelyEarly : .moderatelyLate
                } else {
                    // Severe penalty
                    notePenalty = thresholds.severePenalty
                    noteCritiques[index] = isEarly ? .severelyEarly : .severelyLate
                }

                score += scorePerNote * (1.0 - notePenalty)
            }
            // Notes beyond actual count get 0 score (already accounted for in measurePenalty)
        }

        return VectorEvaluation(
            score: score * measurePenalty,
            noteCritiques: noteCritiques,
            passageCritiques: passageCritiques
        )
    }
}

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
        self.startTimeEvaluator = StartTimeEvaluator(thresholds: .default())
    }

    init(context: EvaluationContext, startTimeThresholds: StartTimeEvaluator.Thresholds) {
        self.context = context
        self.startTimeEvaluator = StartTimeEvaluator(thresholds: startTimeThresholds)
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
