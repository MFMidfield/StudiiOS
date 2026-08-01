//
//  Theme.swift
//  Student OS design tokens — colors, spacing shared across all feature modules.
//

import SwiftUI

enum Theme {
    enum Colors {
        static let primary = Color(hex: "4A7DFF")
        static let danger = Color(hex: "FF6B6B")
        static let warning = Color(hex: "FFB347")
        static let success = Color(hex: "4CAF50")
        static let info = Color(hex: "00BCD4")
        static let purple = Color(hex: "9C27B0")
        static let pink = Color(hex: "E91E63")
        static let indigo = Color(hex: "3F51B5")
        static let textPrimary = Color(hex: "1A1A2E")
        static let background = Color(hex: "F5F6FA")
        static let cardBackground = Color.white
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
