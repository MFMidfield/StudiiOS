//
//  IconTile.swift
//  An SF Symbol on a tinted rounded square — the shared icon treatment for the
//  Dashboard menu, the quick-add grid and schedule rows.
//

import SwiftUI

struct IconTile: View {
    let systemName: String
    /// Side length of the tile. 32 for list rows, 44–48 for the menu, 64 for
    /// the quick-add grid.
    var size: CGFloat = 32
    var tint: Color = Theme.Colors.primaryDeep
    /// Defaults to the soft accent tint. Pass `subject.color.opacity(0.14)` to
    /// tie the tile to a subject's own color.
    var background: Color = Theme.Colors.primarySoft
    var cornerRadius: CGFloat = Theme.Radius.icon

    var body: some View {
        // SF Symbols only render with the system font — never Theme.Font here.
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension IconTile {
    /// Tile tinted with a single color — icon in the color, backdrop a wash of it.
    /// Used where the color already means something (a subject, a task kind).
    init(systemName: String, size: CGFloat = 32, color: Color, cornerRadius: CGFloat = Theme.Radius.icon) {
        self.init(
            systemName: systemName,
            size: size,
            tint: color,
            background: color.opacity(0.14),
            cornerRadius: cornerRadius
        )
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.lg) {
        IconTile(systemName: "calendar")
        IconTile(systemName: "chart.bar", size: 44)
        IconTile(systemName: "graduationcap", size: 64, cornerRadius: 20)
        IconTile(systemName: "book", size: 44, color: Theme.Colors.subjectPalette[1])
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
}
