//
//  ExpandableSection.swift
//  maistro
//

import SwiftUI

struct ExpandableSection<CompactContent: View, ExpandedContent: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isExpanded: Bool

    let compactContent: CompactContent
    let expandedContent: ExpandedContent
    let expandIconSize: CGFloat

    init(
        isExpanded: Binding<Bool>,
        expandIconSize: CGFloat,
        @ViewBuilder compactContent: () -> CompactContent,
        @ViewBuilder expandedContent: () -> ExpandedContent
    ) {
        self._isExpanded = isExpanded
        self.expandIconSize = expandIconSize
        self.compactContent = compactContent()
        self.expandedContent = expandedContent()
    }

    var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                HStack(spacing: 8) {
                    compactContent
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: expandIconSize))
                    .foregroundColor(themeManager.colors.neutralAccent)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isExpanded = false

        var body: some View {
            ExpandableSection(
                isExpanded: $isExpanded,
                expandIconSize: 20,
                compactContent: {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 50, height: 50)
                },
                expandedContent: {
                    VStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.blue)
                            .frame(width: 150, height: 100)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                            .frame(width: 150, height: 100)
                    }
                }
            )
            .padding()
            .background(Color.black)
        }
    }

    return PreviewWrapper()
        .environmentObject(ThemeManager.shared)
}
