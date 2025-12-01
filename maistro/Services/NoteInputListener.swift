//
//  NoteInputListener.swift
//  maistro
//
//  A thread-safe listener for note input events. Runs on a background queue
//  and publishes raw notes as they are completed.

import Foundation
import Combine

/// Events that can be sent to the note input listener
enum NoteInputEvent {
    /// A note has started (e.g., tap down, MIDI note on)
    case noteStart(pitchDeciHz: UInt32, timestampMs: UInt64)

    /// A note has ended (e.g., tap up, MIDI note off)
    case noteEnd(pitchDeciHz: UInt32, timestampMs: UInt64)
}

/// Configuration for the note input listener
struct NoteInputListenerConfig {
    /// Default pitch to use for tap input (B4 = 4939 deciHz)
    let defaultPitchDeciHz: UInt32

    static func rhythmPractice() -> NoteInputListenerConfig {
        NoteInputListenerConfig(defaultPitchDeciHz: 4939)
    }
}

/// Thread-safe listener for note input events
actor NoteInputListener {
    private let config: NoteInputListenerConfig
    private var passageStartTimeMs: UInt64?
    private var activeNotes: [UInt32: UInt64] // pitch -> start timestamp
    private var passage: RawPassage

    // Publisher for completed notes
    private let noteSubject = PassthroughSubject<RawPassageNote, Never>()
    nonisolated var notePublisher: AnyPublisher<RawPassageNote, Never> {
        noteSubject.eraseToAnyPublisher()
    }

    // Publisher for passage updates
    private let passageSubject = PassthroughSubject<RawPassage, Never>()
    nonisolated var passagePublisher: AnyPublisher<RawPassage, Never> {
        passageSubject.eraseToAnyPublisher()
    }

    init(config: NoteInputListenerConfig) {
        self.config = config
        self.activeNotes = [:]
        self.passage = RawPassage.empty()
    }

    /// Record a note start event
    func noteStarted(pitchDeciHz: UInt32, timestampMs: UInt64) {
        // Set passage start time on first note
        if passageStartTimeMs == nil {
            passageStartTimeMs = timestampMs
        }

        // Track the active note
        activeNotes[pitchDeciHz] = timestampMs
    }

    /// Record a note start using the default pitch (for tap input)
    func noteStarted(timestampMs: UInt64) {
        noteStarted(pitchDeciHz: config.defaultPitchDeciHz, timestampMs: timestampMs)
    }

    /// Record a note end event and emit the completed note
    func noteEnded(pitchDeciHz: UInt32, timestampMs: UInt64) {
        guard let startTimestampMs = activeNotes.removeValue(forKey: pitchDeciHz) else {
            return // Note wasn't started, ignore
        }

        guard let passageStart = passageStartTimeMs else {
            return // No passage started, ignore
        }

        let durationMs = timestampMs - startTimestampMs
        let startOffsetMs = startTimestampMs - passageStart

        let rawNote = RawNote(
            pitchDeciHz: pitchDeciHz,
            durationMs: durationMs
        )

        let passageNote = RawPassageNote(
            note: rawNote,
            startOffsetMs: startOffsetMs
        )

        passage.addNote(passageNote)

        // Publish the note and updated passage
        noteSubject.send(passageNote)
        passageSubject.send(passage)
    }

    /// Record a note end using the default pitch (for tap input)
    func noteEnded(timestampMs: UInt64) {
        noteEnded(pitchDeciHz: config.defaultPitchDeciHz, timestampMs: timestampMs)
    }

    /// Get the current timestamp in milliseconds
    nonisolated static func currentTimestampMs() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }

    /// Get the current passage
    func getPassage() -> RawPassage {
        passage
    }

    /// Get the passage start time
    func getPassageStartTimeMs() -> UInt64? {
        passageStartTimeMs
    }

    /// Clear the passage and reset state
    func clear() {
        passageStartTimeMs = nil
        activeNotes.removeAll()
        passage.clear()
        passageSubject.send(passage)
    }
}
