//
//  Theme.swift
//  Student OS design tokens — colors, spacing shared across all feature modules.
//

import SwiftUI

enum Theme {
    enum Colors {
        // Warm accent — split into two tokens because the surface tone
        // (`primary`) doesn't pass AA contrast for text/icons on its own.
        // Use `primary` only as a fill (highlights, progress, dividers);
        // use `primaryDeep` for anything text/icon colored.
        static let primary = Color(light: "E1802F", dark: "F2A65A")
        static let primaryDeep = Color(light: "A85C1C", dark: "F2A65A")
        /// Text/icon color when placed on top of a `primary`-filled surface
        /// (e.g. the "today" circle). Only differs from `textPrimary` in dark mode.
        static let onPrimary = Color(light: "FFFFFF", dark: "1A1512")

        static let danger = Color(hex: "FF6B6B")
        static let warning = Color(hex: "FFB347")
        static let success = Color(hex: "4CAF50")
        static let info = Color(hex: "00BCD4")
        static let purple = Color(hex: "9C27B0")
        static let pink = Color(hex: "E91E63")
        static let indigo = Color(hex: "3F51B5")

        static let textPrimary = Color(light: "2A2320", dark: "F4EEE7")
        static let textSecondary = Color(light: "7A6E62", dark: "A79A8B")
        static let background = Color(light: "FBF7F2", dark: "14110E")
        static let cardBackground = Color(light: "FFFFFF", dark: "1F1B17")
        /// A step lighter than `cardBackground` — for a card nested on top of another card.
        static let surfaceRaised = Color(light: "F6F0E8", dark: "2A241E")
        static let breakBackground = Color(light: "FDF3E0", dark: "2A2416")
        static let separator = Color(light: "EDE3D6", dark: "3A322A")
        /// Hairline border on cards — carries most of the card's edge definition
        /// in dark mode, where a black shadow on a dark background barely reads.
        static let cardStroke = Color(light: "EDE3D6", dark: "3A322A")

        // Muted warm palette for subjects/events — replaces the old bright/cool
        // set, which clashed with the cream background.
        static let subjectPalette: [Color] = [
            primary, Color(hex: "7D8F69"), Color(hex: "C25B4E"), Color(hex: "6B7FA3"),
            Color(hex: "8E6B9E"), Color(hex: "B08D57"), Color(hex: "5F8A8B"), Color(hex: "C2703C"),
        ]
        static let subjectPaletteHex: [String] = [
            "E1802F", "7D8F69", "C25B4E", "6B7FA3", "8E6B9E", "B08D57", "5F8A8B", "C2703C",
        ]
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
