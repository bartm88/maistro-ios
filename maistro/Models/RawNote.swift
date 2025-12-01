//
//  RawNote.swift
//  maistro
//
//  Raw note representation for user input. These are unquantized notes
//  with continuous values that will be snapped to discrete subdivisions.

import Foundation

/// A raw note with continuous pitch and timing values
struct RawNote: Equatable, Codable {
    /// Pitch in decihertz (Hz * 10) for integer precision
    /// A4 = 4400 deciHz, A0 = 275 deciHz, C8 = 41860 deciHz
    let pitchDeciHz: UInt32

    /// Duration in milliseconds
    let durationMs: UInt64
}

/// A raw note with its start time offset within a passage
struct RawPassageNote: Equatable, Codable {
    let note: RawNote

    /// Start offset in milliseconds from passage start
    let startOffsetMs: UInt64
}

/// A collection of raw notes representing a played passage
struct RawPassage: Equatable, Codable {
    /// Notes ordered by start offset
    var notes: [RawPassageNote]

    init(notes: [RawPassageNote]) {
        self.notes = notes
    }

    /// Create an empty passage
    static func empty() -> RawPassage {
        RawPassage(notes: [])
    }

    /// Add a note to the passage
    mutating func addNote(_ note: RawPassageNote) {
        notes.append(note)
        // Keep sorted by start offset
        notes.sort { $0.startOffsetMs < $1.startOffsetMs }
    }

    /// Clear all notes
    mutating func clear() {
        notes.removeAll()
    }
}
