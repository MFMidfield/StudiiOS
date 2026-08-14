//
//  GhostEventLayer.swift
//  The floating pill CalendarView draws while a long-press-drag is in
//  progress (create new event / move an existing event or task). Purely
//  visual — CalendarView owns all the gesture/state logic since the ghost
//  needs direct access to its grid geometry and model context.
//

import SwiftUI

struct GhostPillView: View {
    let label: String
    let color: Color
    let scale: CGFloat
    let position: CGPoint

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.Colors.cardBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8)
        .scaleEffect(scale)
        .position(position)
        .allowsHitTesting(false)
    }
}
