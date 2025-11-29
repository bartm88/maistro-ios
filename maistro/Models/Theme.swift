//
//  Theme.swift
//  maistro
//

import SwiftUI

enum Theme: String, CaseIterable, Identifiable {
    case amber = "amber"
    case blue = "blue"
    case green = "green"
    case neon = "neon"
    case greyscale = "greyscale"
    case ocean = "ocean"
    case red = "red"
    case sunset = "sunset"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .amber: return "Amber"
        case .blue: return "Blue"
        case .green: return "Green"
        case .neon: return "Neon"
        case .greyscale: return "Greyscale"
        case .ocean: return "Ocean"
        case .red: return "Red"
        case .sunset: return "Sunset"
        }
    }

    var colors: ThemeColors {
        switch self {
        case .amber:
            return ThemeColors(
                primary: Color(red: 0.992, green: 0.835, blue: 0.518),      // amber-300
                textPrimary: Color(red: 0.451, green: 0.231, blue: 0.020),   // amber-900
                primaryHover: Color(red: 1.0, green: 0.984, blue: 0.922),    // amber-50
                primaryAccent: Color(red: 0.851, green: 0.565, blue: 0.035), // amber-600
                secondary: Color(red: 0.451, green: 0.231, blue: 0.020),     // amber-900
                textSecondary: Color(red: 0.996, green: 0.925, blue: 0.749), // amber-200
                secondaryHover: Color(red: 0.706, green: 0.427, blue: 0.051),// amber-700
                secondaryAccent: Color(red: 0.957, green: 0.686, blue: 0.161), // amber-500
                neutral: Color(red: 0.996, green: 0.945, blue: 0.835),       // amber-100
                textNeutral: Color(red: 0.706, green: 0.427, blue: 0.051),   // amber-700
                neutralHover: Color(red: 0.992, green: 0.835, blue: 0.518),  // amber-300
                neutralAccent: Color(red: 0.851, green: 0.565, blue: 0.035), // amber-600
                confirmation: Color(red: 0.020, green: 0.494, blue: 0.294),  // green-700
                textConfirmation: Color(red: 0.733, green: 0.949, blue: 0.827), // green-200
                confirmationHover: Color(red: 0.314, green: 0.859, blue: 0.569), // green-400
                confirmationAccent: Color(red: 0.133, green: 0.690, blue: 0.431), // green-500
                negative: Color(red: 0.863, green: 0.153, blue: 0.157),      // red-600
                textNegative: Color(red: 0.996, green: 0.741, blue: 0.745),  // red-200
                negativeHover: Color(red: 0.965, green: 0.388, blue: 0.396),  // red-400
                negativeAccent: Color(red: 0.988, green: 0.592, blue: 0.596)  // red-300
            )
        case .blue:
            return ThemeColors(
                primary: Color(red: 0.576, green: 0.769, blue: 0.992),      // blue-300
                textPrimary: Color(red: 0.118, green: 0.224, blue: 0.420),   // blue-900
                primaryHover: Color(red: 0.937, green: 0.961, blue: 1.0),    // blue-50
                primaryAccent: Color(red: 0.153, green: 0.435, blue: 0.859), // blue-600
                secondary: Color(red: 0.118, green: 0.224, blue: 0.420),     // blue-900
                textSecondary: Color(red: 0.749, green: 0.847, blue: 0.996), // blue-200
                secondaryHover: Color(red: 0.118, green: 0.337, blue: 0.655),// blue-700
                secondaryAccent: Color(red: 0.231, green: 0.584, blue: 0.929), // blue-500
                neutral: Color(red: 0.875, green: 0.918, blue: 0.996),       // blue-100
                textNeutral: Color(red: 0.118, green: 0.337, blue: 0.655),   // blue-700
                neutralHover: Color(red: 0.576, green: 0.769, blue: 0.992),  // blue-300
                neutralAccent: Color(red: 0.153, green: 0.435, blue: 0.859), // blue-600
                confirmation: Color(red: 0.020, green: 0.494, blue: 0.294),  // green-700
                textConfirmation: Color(red: 0.733, green: 0.949, blue: 0.827), // green-200
                confirmationHover: Color(red: 0.314, green: 0.859, blue: 0.569), // green-400
                confirmationAccent: Color(red: 0.133, green: 0.690, blue: 0.431), // green-500
                negative: Color(red: 0.863, green: 0.153, blue: 0.157),      // red-600
                textNegative: Color(red: 0.996, green: 0.741, blue: 0.745),  // red-200
                negativeHover: Color(red: 0.965, green: 0.388, blue: 0.396),  // red-400
                negativeAccent: Color(red: 0.988, green: 0.592, blue: 0.596)  // red-300
            )
        case .green:
            return ThemeColors(
                primary: Color(red: 0.537, green: 0.906, blue: 0.706),      // green-300
                textPrimary: Color(red: 0.047, green: 0.329, blue: 0.192),   // green-900
                primaryHover: Color(red: 0.941, green: 0.996, blue: 0.969),  // green-50
                primaryAccent: Color(red: 0.071, green: 0.576, blue: 0.345), // green-600
                secondary: Color(red: 0.047, green: 0.329, blue: 0.192),     // green-900
                textSecondary: Color(red: 0.733, green: 0.949, blue: 0.827), // green-200
                secondaryHover: Color(red: 0.020, green: 0.494, blue: 0.294),// green-700
                secondaryAccent: Color(red: 0.133, green: 0.690, blue: 0.431), // green-500
                neutral: Color(red: 0.863, green: 0.976, blue: 0.918),       // green-100
                textNeutral: Color(red: 0.020, green: 0.494, blue: 0.294),   // green-700
                neutralHover: Color(red: 0.537, green: 0.906, blue: 0.706),  // green-300
                neutralAccent: Color(red: 0.071, green: 0.576, blue: 0.345), // green-600
                confirmation: Color(red: 0.118, green: 0.337, blue: 0.655),  // blue-700
                textConfirmation: Color(red: 0.749, green: 0.847, blue: 0.996), // blue-200
                confirmationHover: Color(red: 0.380, green: 0.663, blue: 0.965), // blue-400
                confirmationAccent: Color(red: 0.231, green: 0.584, blue: 0.929), // blue-500
                negative: Color(red: 0.863, green: 0.153, blue: 0.157),      // red-600
                textNegative: Color(red: 0.996, green: 0.741, blue: 0.745),  // red-200
                negativeHover: Color(red: 0.965, green: 0.388, blue: 0.396),  // red-400
                negativeAccent: Color(red: 0.988, green: 0.592, blue: 0.596)  // red-300
            )
        case .neon:
            return ThemeColors(
                primary: Color(red: 0.110, green: 0.110, blue: 0.114),      // neutral-900
                textPrimary: Color(red: 0.651, green: 0.384, blue: 0.878),   // purple-500
                primaryHover: Color(red: 0.322, green: 0.329, blue: 0.337),  // neutral-600
                primaryAccent: Color(red: 0.863, green: 0.737, blue: 0.996), // purple-200
                secondary: Color(red: 0.231, green: 0.584, blue: 0.929),     // blue-500
                textSecondary: Color(red: 0.749, green: 0.847, blue: 0.996), // blue-200
                secondaryHover: Color(red: 0.118, green: 0.337, blue: 0.655),// blue-700
                secondaryAccent: Color(red: 0.576, green: 0.769, blue: 0.992), // blue-300
                neutral: Color(red: 0.898, green: 0.898, blue: 0.902),       // neutral-200
                textNeutral: Color(red: 0.231, green: 0.584, blue: 0.929),   // blue-500
                neutralHover: Color(red: 0.980, green: 0.980, blue: 0.980),  // neutral-50
                neutralAccent: Color(red: 0.482, green: 0.208, blue: 0.867), // purple-600
                confirmation: Color(red: 0.133, green: 0.690, blue: 0.431),  // green-500
                textConfirmation: Color(red: 0.941, green: 0.996, blue: 0.969), // green-50
                confirmationHover: Color(red: 0.020, green: 0.494, blue: 0.294), // green-700
                confirmationAccent: Color(red: 0.537, green: 0.906, blue: 0.706), // green-300
                negative: Color(red: 0.937, green: 0.263, blue: 0.278),      // red-500
                textNegative: Color(red: 0.996, green: 0.949, blue: 0.949),  // red-50
                negativeHover: Color(red: 0.725, green: 0.059, blue: 0.082),  // red-700
                negativeAccent: Color(red: 0.988, green: 0.592, blue: 0.596)  // red-300
            )
        case .greyscale:
            return ThemeColors(
                primary: Color(red: 0.902, green: 0.906, blue: 0.914),      // gray-200
                textPrimary: Color(red: 0.122, green: 0.125, blue: 0.133),   // gray-800
                primaryHover: Color(red: 0.976, green: 0.976, blue: 0.980),  // gray-100
                primaryAccent: Color(red: 0.627, green: 0.635, blue: 0.655), // gray-400
                secondary: Color(red: 0.122, green: 0.125, blue: 0.133),     // gray-800
                textSecondary: Color(red: 0.902, green: 0.906, blue: 0.914), // gray-200
                secondaryHover: Color(red: 0.322, green: 0.329, blue: 0.345),// gray-600
                secondaryAccent: Color(red: 0.431, green: 0.439, blue: 0.463), // gray-500
                neutral: Color(red: 0.831, green: 0.835, blue: 0.851),       // gray-300
                textNeutral: Color(red: 0.239, green: 0.243, blue: 0.259),   // gray-700
                neutralHover: Color(red: 0.627, green: 0.635, blue: 0.655),  // gray-400
                neutralAccent: Color(red: 0.322, green: 0.329, blue: 0.345), // gray-600
                confirmation: Color(red: 0.322, green: 0.329, blue: 0.345),  // gray-600
                textConfirmation: Color(red: 0.976, green: 0.976, blue: 0.980), // gray-100
                confirmationHover: Color(red: 0.431, green: 0.439, blue: 0.463), // gray-500
                confirmationAccent: Color(red: 0.431, green: 0.439, blue: 0.463), // gray-500
                negative: Color(red: 0.239, green: 0.243, blue: 0.259),      // gray-700
                textNegative: Color(red: 0.902, green: 0.906, blue: 0.914),  // gray-200
                negativeHover: Color(red: 0.322, green: 0.329, blue: 0.345),  // gray-600
                negativeAccent: Color(red: 0.431, green: 0.439, blue: 0.463)  // gray-500
            )
        case .ocean:
            return ThemeColors(
                primary: Color(red: 0.368, green: 0.851, blue: 0.788),      // teal-300
                textPrimary: Color(red: 0.051, green: 0.329, blue: 0.310),   // teal-900
                primaryHover: Color(red: 0.941, green: 0.996, blue: 0.992),  // teal-50
                primaryAccent: Color(red: 0.047, green: 0.576, blue: 0.537), // teal-600
                secondary: Color(red: 0.024, green: 0.314, blue: 0.400),     // cyan-900
                textSecondary: Color(red: 0.655, green: 0.914, blue: 0.976), // cyan-200
                secondaryHover: Color(red: 0.024, green: 0.478, blue: 0.604),// cyan-700
                secondaryAccent: Color(red: 0.043, green: 0.718, blue: 0.894), // cyan-500
                neutral: Color(red: 0.800, green: 0.976, blue: 0.961),       // teal-100
                textNeutral: Color(red: 0.035, green: 0.455, blue: 0.424),   // teal-700
                neutralHover: Color(red: 0.368, green: 0.851, blue: 0.788),  // teal-300
                neutralAccent: Color(red: 0.047, green: 0.576, blue: 0.537), // teal-600
                confirmation: Color(red: 0.004, green: 0.490, blue: 0.396),  // emerald-700
                textConfirmation: Color(red: 0.655, green: 0.976, blue: 0.906), // emerald-200
                confirmationHover: Color(red: 0.212, green: 0.835, blue: 0.596), // emerald-400
                confirmationAccent: Color(red: 0.059, green: 0.690, blue: 0.522), // emerald-500
                negative: Color(red: 0.863, green: 0.153, blue: 0.157),      // red-600
                textNegative: Color(red: 0.996, green: 0.741, blue: 0.745),  // red-200
                negativeHover: Color(red: 0.965, green: 0.388, blue: 0.396),  // red-400
                negativeAccent: Color(red: 0.988, green: 0.592, blue: 0.596)  // red-300
            )
        case .red:
            return ThemeColors(
                primary: Color(red: 0.988, green: 0.592, blue: 0.596),      // red-300
                textPrimary: Color(red: 0.459, green: 0.039, blue: 0.047),   // red-900
                primaryHover: Color(red: 0.996, green: 0.949, blue: 0.949),  // red-50
                primaryAccent: Color(red: 0.863, green: 0.153, blue: 0.157), // red-600
                secondary: Color(red: 0.459, green: 0.039, blue: 0.047),     // red-900
                textSecondary: Color(red: 0.996, green: 0.741, blue: 0.745), // red-200
                secondaryHover: Color(red: 0.725, green: 0.059, blue: 0.082),// red-700
                secondaryAccent: Color(red: 0.937, green: 0.263, blue: 0.278), // red-500
                neutral: Color(red: 0.996, green: 0.886, blue: 0.886),       // red-100
                textNeutral: Color(red: 0.725, green: 0.059, blue: 0.082),   // red-700
                neutralHover: Color(red: 0.988, green: 0.592, blue: 0.596),  // red-300
                neutralAccent: Color(red: 0.863, green: 0.153, blue: 0.157), // red-600
                confirmation: Color(red: 0.020, green: 0.494, blue: 0.294),  // green-700
                textConfirmation: Color(red: 0.733, green: 0.949, blue: 0.827), // green-200
                confirmationHover: Color(red: 0.314, green: 0.859, blue: 0.569), // green-400
                confirmationAccent: Color(red: 0.133, green: 0.690, blue: 0.431), // green-500
                negative: Color(red: 0.918, green: 0.635, blue: 0.063),      // yellow-600
                textNegative: Color(red: 0.996, green: 0.937, blue: 0.733),  // yellow-200
                negativeHover: Color(red: 0.984, green: 0.804, blue: 0.353),  // yellow-400
                negativeAccent: Color(red: 0.996, green: 0.863, blue: 0.529)  // yellow-300
            )
        case .sunset:
            return ThemeColors(
                primary: Color(red: 0.992, green: 0.710, blue: 0.482),      // orange-300
                textPrimary: Color(red: 0.459, green: 0.184, blue: 0.020),   // orange-900
                primaryHover: Color(red: 1.0, green: 0.969, blue: 0.933),    // orange-50
                primaryAccent: Color(red: 0.918, green: 0.420, blue: 0.063), // orange-600
                secondary: Color(red: 0.529, green: 0.039, blue: 0.267),     // pink-900
                textSecondary: Color(red: 0.988, green: 0.729, blue: 0.898), // pink-200
                secondaryHover: Color(red: 0.753, green: 0.090, blue: 0.408),// pink-700
                secondaryAccent: Color(red: 0.922, green: 0.286, blue: 0.651), // pink-500
                neutral: Color(red: 1.0, green: 0.933, blue: 0.882),         // orange-100
                textNeutral: Color(red: 0.757, green: 0.325, blue: 0.043),   // orange-700
                neutralHover: Color(red: 0.992, green: 0.710, blue: 0.482),  // orange-300
                neutralAccent: Color(red: 0.918, green: 0.420, blue: 0.063), // orange-600
                confirmation: Color(red: 0.020, green: 0.494, blue: 0.294),  // green-700
                textConfirmation: Color(red: 0.733, green: 0.949, blue: 0.827), // green-200
                confirmationHover: Color(red: 0.314, green: 0.859, blue: 0.569), // green-400
                confirmationAccent: Color(red: 0.133, green: 0.690, blue: 0.431), // green-500
                negative: Color(red: 0.863, green: 0.153, blue: 0.157),      // red-600
                textNegative: Color(red: 0.996, green: 0.741, blue: 0.745),  // red-200
                negativeHover: Color(red: 0.965, green: 0.388, blue: 0.396),  // red-400
                negativeAccent: Color(red: 0.988, green: 0.592, blue: 0.596)  // red-300
            )
        }
    }
}

struct ThemeColors {
    let primary: Color
    let textPrimary: Color
    let primaryHover: Color
    let primaryAccent: Color

    let secondary: Color
    let textSecondary: Color
    let secondaryHover: Color
    let secondaryAccent: Color

    let neutral: Color
    let textNeutral: Color
    let neutralHover: Color
    let neutralAccent: Color

    let confirmation: Color
    let textConfirmation: Color
    let confirmationHover: Color
    let confirmationAccent: Color

    let negative: Color
    let textNegative: Color
    let negativeHover: Color
    let negativeAccent: Color
}
