//
//  StartTimeEvaluator.swift
//  maistro
//
//  Evaluates the timing accuracy of note start times.
//  Groups notes by start time (chords) to treat them as single rhythm entities.

import Foundation

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

    /// Tolerance for grouping notes into chords (in milliseconds)
    /// Notes within this window are considered simultaneous
    let chordToleranceMs: Double
    let thresholds: Thresholds

    init(thresholds: Thresholds, chordToleranceMs: Double) {
        self.thresholds = thresholds
        self.chordToleranceMs = chordToleranceMs
    }

    func evaluate(
        expected: RawPassage,
        actual: RawPassage,
        context: EvaluationContext
    ) -> VectorEvaluation {
        var passageCritiques: Set<String> = []
        var noteCritiques: [Int: NoteCritique] = [:]
        var score = 0.0

        // Group notes by start time to create rhythm entities (chords)
        let expectedEntities = groupNotesIntoRhythmEntities(notes: expected.notes, toleranceMs: 0)
        let actualEntities = groupNotesIntoRhythmEntities(notes: actual.notes, toleranceMs: chordToleranceMs)

        // Penalize for wrong number of rhythm entities
        var measurePenalty = 1.0
        if actualEntities.count < expectedEntities.count {
            passageCritiques.insert("Missed notes")
            measurePenalty = Double(actualEntities.count) / Double(expectedEntities.count)
        } else if actualEntities.count > expectedEntities.count {
            passageCritiques.insert("Extra notes")
            measurePenalty = Double(expectedEntities.count) / Double(actualEntities.count)
        }

        guard !expectedEntities.isEmpty else {
            return VectorEvaluation(
                score: actualEntities.isEmpty ? 1.0 : 0.0,
                noteCritiques: [:],
                passageCritiques: passageCritiques
            )
        }

        let scorePerEntity = 1.0 / Double(expectedEntities.count)
        let subdivisionDurationMs = context.subdivisionDurationMs

        // Evaluate each rhythm entity
        for (index, expectedEntity) in expectedEntities.enumerated() {
            var entityPenalty = 0.0

            if index < actualEntities.count {
                let actualEntity = actualEntities[index]
                let distance = abs(Int64(actualEntity.startTime) - Int64(expectedEntity.startTime))
                let distanceDouble = Double(distance)

                let isEarly = actualEntity.startTime < expectedEntity.startTime

                // Determine penalty based on thresholds
                if distanceDouble < subdivisionDurationMs * thresholds.noPenaltyFraction {
                    // Within tolerance, no penalty
                    entityPenalty = 0.0
                } else if distanceDouble < subdivisionDurationMs * thresholds.slightPenaltyFraction {
                    // Slight penalty
                    entityPenalty = thresholds.slightPenalty
                    // Apply critique to all notes in this entity
                    for noteIndex in expectedEntity.noteIndices {
                        noteCritiques[noteIndex] = isEarly ? .slightlyEarly : .slightlyLate
                    }
                } else if distanceDouble < subdivisionDurationMs * thresholds.moderatePenaltyFraction {
                    // Moderate penalty
                    entityPenalty = thresholds.moderatePenalty
                    for noteIndex in expectedEntity.noteIndices {
                        noteCritiques[noteIndex] = isEarly ? .moderatelyEarly : .moderatelyLate
                    }
                } else {
                    // Severe penalty
                    entityPenalty = thresholds.severePenalty
                    for noteIndex in expectedEntity.noteIndices {
                        noteCritiques[noteIndex] = isEarly ? .severelyEarly : .severelyLate
                    }
                }

                score += scorePerEntity * (1.0 - entityPenalty)
            }
            // Entities beyond actual count get 0 score (already accounted for in measurePenalty)
        }

        return VectorEvaluation(
            score: score * measurePenalty,
            noteCritiques: noteCritiques,
            passageCritiques: passageCritiques
        )
    }

    /// Groups notes that start at approximately the same time into rhythm entities (chords)
    /// - Parameters:
    ///   - notes: The notes to group
    ///   - toleranceMs: Maximum time difference to consider notes simultaneous
    /// - Returns: Array of rhythm entities, sorted by start time
    private func groupNotesIntoRhythmEntities(
        notes: [RawPassageNote],
        toleranceMs: Double
    ) -> [RhythmEntity] {
        guard !notes.isEmpty else { return [] }

        // Sort notes by start time
        let sortedNotes = notes.enumerated().sorted { $0.element.startOffsetMs < $1.element.startOffsetMs }

        var entities: [RhythmEntity] = []
        var currentGroup: [(index: Int, note: RawPassageNote)] = []
        var currentGroupStartTime: UInt64?

        for (originalIndex, note) in sortedNotes {
            if let groupStartTime = currentGroupStartTime {
                let timeDiff = abs(Int64(note.startOffsetMs) - Int64(groupStartTime))
                if Double(timeDiff) <= toleranceMs {
                    // Add to current group
                    currentGroup.append((originalIndex, note))
                } else {
                    // Start new group
                    entities.append(RhythmEntity(
                        startTime: groupStartTime,
                        noteIndices: currentGroup.map { $0.index },
                        noteCount: currentGroup.count
                    ))
                    currentGroup = [(originalIndex, note)]
                    currentGroupStartTime = note.startOffsetMs
                }
            } else {
                // First note
                currentGroup = [(originalIndex, note)]
                currentGroupStartTime = note.startOffsetMs
            }
        }

        // Add final group
        if let groupStartTime = currentGroupStartTime {
            entities.append(RhythmEntity(
                startTime: groupStartTime,
                noteIndices: currentGroup.map { $0.index },
                noteCount: currentGroup.count
            ))
        }

        return entities
    }
}

/// Represents a rhythm entity (single note or chord) at a specific time
private struct RhythmEntity {
    /// Start time of this rhythm entity
    let startTime: UInt64

    /// Indices of notes in the original passage that belong to this entity
    let noteIndices: [Int]

    /// Number of notes in this entity (1 for single note, >1 for chord)
    let noteCount: Int
}
