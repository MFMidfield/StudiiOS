//
//  Theme.swift
//  Student OS design tokens — colors, spacing shared across all feature modules.
//

import SwiftUI

enum Theme {
    enum Colors {
        // Accent colors keep a single fixed hue across appearances — only
        // surfaces/text need to invert for dark mode.
        static let primary = Color(hex: "4A7DFF")
        static let danger = Color(hex: "FF6B6B")
        static let warning = Color(hex: "FFB347")
        static let success = Color(hex: "4CAF50")
        static let info = Color(hex: "00BCD4")
        static let purple = Color(hex: "9C27B0")
        static let pink = Color(hex: "E91E63")
        static let indigo = Color(hex: "3F51B5")

        static let textPrimary = Color(light: "1A1A2E", dark: "F2F3F7")
        static let textSecondary = Color(light: "6B7280", dark: "9A9FB0")
        static let background = Color(light: "F5F6FA", dark: "0E0F14")
        static let cardBackground = Color(light: "FFFFFF", dark: "1B1D26")
        /// A step lighter than `cardBackground` — for a card nested on top of another card.
        static let surfaceRaised = Color(light: "F5F6FA", dark: "252836")
        static let breakBackground = Color(light: "FFF8E7", dark: "2A2416")
        static let separator = Color(light: "E8EAF0", dark: "2C2F3A")
        /// Hairline border on cards — carries most of the card's edge definition
        /// in dark mode, where a black shadow on a dark background barely reads.
        static let cardStroke = Color(light: "E8EAF0", dark: "323544")

        static let subjectPalette: [Color] = [primary, success, warning, danger, purple, pink, indigo, info]
        static let subjectPaletteHex: [String] = ["4A7DFF", "4CAF50", "FFB347", "FF6B6B", "9C27B0", "E91E63", "3F51B5", "00BCD4"]
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
        static let hero: CGFloat = 22
    }
}

/// Reusable card container matching the Dashboard's visual style.
struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            content
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.cardStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

/// Small badge used to mark Pro/Plus-gated features throughout the app.
struct TierBadge: View {
    let tier: FeatureTier

    var body: some View {
        if tier != .free {
            Text(tier.label)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(tier.color.opacity(0.15))
                .foregroundStyle(tier.color)
                .clipShape(Capsule())
        }
    }
}
