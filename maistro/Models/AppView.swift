//
//  AppView.swift
//  maistro
//

import Foundation

enum AppView: String, CaseIterable, Identifiable {
    case landing
    case cards
    case sandbox
    case themeTester
    case rhythm
    case pitch
    case song
    case sightread
    case improvisation

    var id: String { rawValue }
}

struct CardData: Identifiable {
    let id: String
    let title: String
    let description: String
    let view: AppView
    let disabled: Bool
}

let appCards: [CardData] = [
    CardData(
        id: "sandbox",
        title: "Sandbox",
        description: "Experiment with music creation and playback",
        view: .sandbox,
        disabled: true
    ),
    CardData(
        id: "rhythm",
        title: "Rhythm Practice",
        description: "Practice rhythm patterns and timing",
        view: .rhythm,
        disabled: false
    ),
    CardData(
        id: "themeTester",
        title: "Theme Tester",
        description: "Visually inspect themes",
        view: .themeTester,
        disabled: false
    ),
    CardData(
        id: "pitch",
        title: "Pitch Training",
        description: "Improve your pitch recognition",
        view: .pitch,
        disabled: true
    ),
    CardData(
        id: "song",
        title: "Song Learning",
        description: "Learn to play your favorite songs",
        view: .song,
        disabled: true
    ),
    CardData(
        id: "sightread",
        title: "Sight Reading",
        description: "Practice sight reading",
        view: .sightread,
        disabled: true
    ),
    CardData(
        id: "improvisation",
        title: "Improvisation",
        description: "Improvise over a backing track",
        view: .improvisation,
        disabled: true
    )
]
