//
//  MusicNotation.swift
//  maistro
//
//  Models for discrete music notation, matching the Rust/TypeScript types in maistro-old

import Foundation

// MARK: - Time Signature

struct TimeSignature: Codable, Equatable {
    let numerator: Int
    let denominator: Int

    init(_ numerator: Int, _ denominator: Int) {
        self.numerator = numerator
        self.denominator = denominator
    }

    init?(string: String) {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let num = Int(parts[0]),
              let denom = Int(parts[1]) else {
            return nil
        }
        self.numerator = num
        self.denominator = denom
    }

    var displayString: String {
        "\(numerator)/\(denominator)"
    }

    /// Number of subdivisions in one measure at the given resolution
    /// - Parameter smallestSubdivision: The smallest note value (e.g., 8 for eighths, 16 for sixteenths)
    func subdivisionsPerMeasure(smallestSubdivision: Int) -> Int {
        // e.g., 4/4 with subdivision=8 -> 8 eighths
        // e.g., 4/4 with subdivision=16 -> 16 sixteenths
        return numerator * smallestSubdivision / denominator
    }

    /// Returns the subdivision positions where strong beats occur.
    /// Strong beats should not be obscured by notes/rests spanning across them.
    /// - Parameter smallestSubdivision: The smallest note value resolution
    /// - Returns: Array of subdivision positions that are strong beats
    func strongBeatPositions(smallestSubdivision: Int) -> [Int] {
        let subdivisionsPerBeat = smallestSubdivision / denominator

        // Determine which beats are strong based on time signature
        let strongBeats: [Int]
        switch (numerator, denominator) {
        // Simple time signatures
        case (4, 4):
            // Beat 1 and beat 3 are strong
            strongBeats = [0, 2]
        case (3, 4):
            // Only beat 1 is strong
            strongBeats = [0]
        case (2, 4):
            // Only beat 1 is strong
            strongBeats = [0]
        case (2, 2):
            // Beat 1 is strong
            strongBeats = [0]
        // Compound time signatures (denominator 8, numerator divisible by 3)
        case (6, 8):
            // Two groups of 3: beats 1 and 4 (indices 0, 3)
            strongBeats = [0, 3]
        case (9, 8):
            // Three groups of 3: beats 1, 4, 7 (indices 0, 3, 6)
            strongBeats = [0, 3, 6]
        case (12, 8):
            // Four groups of 3: beats 1, 4, 7, 10 (indices 0, 3, 6, 9)
            strongBeats = [0, 3, 6, 9]
        default:
            // For other signatures, treat each beat as a strong beat boundary
            // This ensures proper notation at beat boundaries
            strongBeats = Array(0..<numerator)
        }

        return strongBeats.map { $0 * subdivisionsPerBeat }
    }
}

// MARK: - Duration Representation

struct DenominatorDots: Codable, Equatable {
    let denominator: Int  // 1=whole, 2=half, 4=quarter, 8=eighth, 16=sixteenth
    let dots: Int

    /// Duration in subdivisions based on resolution
    func subdivisionDuration(resolution: Int) -> Int {
        let baseDuration = resolution / denominator
        switch dots {
        case 0: return baseDuration
        case 1: return baseDuration * 3 / 2
        case 2: return baseDuration * 7 / 4
        default: return baseDuration
        }
    }

    /// Convert to VexFlow duration string (e.g., "4", "4.", "2..")
    var vexFlowDuration: String {
        "\(denominator)" + String(repeating: ".", count: dots)
    }
}

// MARK: - Discrete Elements

struct DiscreteNote: Codable, Equatable {
    let noteName: String  // e.g., "A4", "C#5", "Bb3"
    let noteDurations: [DenominatorDots]

    /// Total duration in subdivisions
    func totalSubdivisionDuration(resolution: Int) -> Int {
        noteDurations.reduce(0) { $0 + $1.subdivisionDuration(resolution: resolution) }
    }
}

struct DiscreteRest: Codable, Equatable {
    let restDurations: [DenominatorDots]

    /// Total duration in subdivisions
    func totalSubdivisionDuration(resolution: Int) -> Int {
        restDurations.reduce(0) { $0 + $1.subdivisionDuration(resolution: resolution) }
    }
}

enum DiscreteElement: Codable, Equatable {
    case note(DiscreteNote)
    case rest(DiscreteRest)

    // Custom coding to match Rust's enum serialization format
    enum CodingKeys: String, CodingKey {
        case Note, Rest
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let note = try container.decodeIfPresent(DiscreteNote.self, forKey: .Note) {
            self = .note(note)
        } else if let rest = try container.decodeIfPresent(DiscreteRest.self, forKey: .Rest) {
            self = .rest(rest)
        } else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid DiscreteElement"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .note(let note):
            try container.encode(note, forKey: .Note)
        case .rest(let rest):
            try container.encode(rest, forKey: .Rest)
        }
    }
}

// MARK: - Measure Elements

struct DiscreteMeasureElement: Codable, Equatable {
    let element: DiscreteElement
    let startSubdivision: Int
    /// If true, this note is a continuation from the previous measure and should be tied
    let tiedFromPrevious: Bool
}

struct DiscreteMeasure: Codable, Equatable {
    let subdivisionDenominator: Int  // Usually 8 for eighth-note resolution
    let elements: [DiscreteMeasureElement]
}

struct DiscretePassage: Codable, Equatable {
    let measures: [DiscreteMeasure]
}

// MARK: - VexFlow Conversion

extension DiscretePassage {
    /// Convert passage to VexFlow EasyScore notation string
    /// Format: "note/duration, note/duration" for each measure
    func toVexFlowNotation() -> [[String]] {
        measures.map { measure in
            measure.elements.flatMap { element -> [String] in
                switch element.element {
                case .note(let note):
                    return note.noteDurations.map { duration in
                        "\(note.noteName)/\(duration.vexFlowDuration)"
                    }
                case .rest(let rest):
                    return rest.restDurations.map { duration in
                        "B4/\(duration.vexFlowDuration)/r"
                    }
                }
            }
        }
    }

    /// Convert to simple notation string for single-voice rendering
    func toSimpleNotation() -> String {
        let allNotes = measures.flatMap { measure in
            measure.elements.flatMap { element -> [String] in
                switch element.element {
                case .note(let note):
                    return note.noteDurations.map { duration in
                        "\(note.noteName)/\(duration.vexFlowDuration)"
                    }
                case .rest(let rest):
                    return rest.restDurations.map { duration in
                        "B4/\(duration.vexFlowDuration)/r"
                    }
                }
            }
        }
        return allNotes.joined(separator: ", ")
    }
}
