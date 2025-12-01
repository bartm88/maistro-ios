//
//  CompactMetronomeButton.swift
//  maistro
//

import SwiftUI

struct CompactMetronomeButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var engine: MetronomeEngine

    let size: CGFloat
    let onTap: (() -> Void)?

    var body: some View {
        Button(action: {
            if let onTap = onTap {
                onTap()
            } else {
                engine.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(engine.isPlaying ? themeManager.colors.negative : themeManager.colors.primary)
                    .frame(width: size, height: size)

                Image(systemName: engine.isPlaying ? "stop.fill" : "metronome.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundColor(engine.isPlaying ? themeManager.colors.textNegative : themeManager.colors.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 20) {
        CompactMetronomeButton(
            engine: MetronomeEngine(),
            size: 50,
            onTap: nil
        )
    }
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager.shared)
}
