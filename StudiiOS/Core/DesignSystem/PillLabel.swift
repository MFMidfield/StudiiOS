//
//  PillLabel.swift
//  Capsule-shaped label used for due-date badges, room numbers, counts and
//  any other short status text that needs to read as a chip rather than prose.
//

import SwiftUI

struct PillLabel: View {
    /// Semantic color pairing. `danger`/`warning` carry meaning (overdue, needs
    /// attention) — don't use them decoratively.
    enum Tone {
        /// Today / active — accent text on the soft accent tint.
        case accent
        /// Default — muted text on a raised surface.
        case neutral
        /// Overdue, deleted, over the limit.
        case danger
        /// Approaching a deadline.
        case warning
        /// Any other pairing, e.g. a subject's own color.
        case custom(foreground: Color, background: Color)

        var foreground: Color {
            switch self {
            case .accent: return Theme.Colors.primaryDeep
            case .neutral: return Theme.Colors.textSecondary
            case .danger: return Theme.Colors.danger
            case .warning: return Theme.Colors.warning
            case .custom(let foreground, _): return foreground
            }
        }

        var background: Color {
            switch self {
            case .accent: return Theme.Colors.primarySoft
            case .neutral: return Theme.Colors.surfaceRaised
            case .danger: return Theme.Colors.danger.opacity(0.12)
            case .warning: return Theme.Colors.warning.opacity(0.16)
            case .custom(_, let background): return background
            }
        }
    }

    let text: String
    var systemImage: String?
    var tone: Tone = .neutral

    init(_ text: String, systemImage: String? = nil, tone: Tone = .neutral) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(Theme.Font.plex(11, .medium))
        }
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(tone.background)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        PillLabel("วันนี้", tone: .accent)
        PillLabel("เลยกำหนด 2 วัน", systemImage: "exclamationmark.triangle.fill", tone: .danger)
        PillLabel("พรุ่งนี้", tone: .warning)
        PillLabel("ห้อง 431")
        PillLabel("3 งาน", tone: .custom(foreground: .white, background: Theme.Colors.primary))
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
}
