//
//  Theme.swift
//  Student OS design tokens — colors, spacing, radii, typography shared
//  across all feature modules.
//

import SwiftUI
import UIKit

enum Theme {
    enum Colors {
        // Warm terracotta accent — split into two tokens because the surface tone
        // (`primary`) doesn't pass AA contrast for text/icons on its own.
        // Use `primary` only as a fill (highlights, progress, dividers);
        // use `primaryDeep` for anything text/icon colored.
        static let primary = Color(light: "C96F4A", dark: "E8A06B")
        static let primaryDeep = Color(light: "A85236", dark: "E8A06B")
        /// Text/icon color when placed on top of a `primary`-filled surface
        /// (e.g. the "today" circle). Only differs from `textPrimary` in dark mode.
        static let onPrimary = Color(light: "FFFFFF", dark: "1A1512")
        /// Tinted backdrop for menu icon tiles, day chips and pills — the accent
        /// diluted far enough that `primaryDeep` text stays readable on it.
        static let primarySoft = Color(light: "F5E7DD", dark: "332720")

        /// Saturated fill for the Dashboard hero card ("คาบเรียนถัดไป").
        static let heroFill = Color(light: "C96F4A", dark: "8F4A2C")
        /// Headline text/icons on top of `heroFill`.
        static let onHero = Color(light: "FFFFFF", dark: "FFF1E6")
        /// Secondary lines on top of `heroFill` — dimmed but still AA on the fill.
        static let onHeroMuted = Color(light: "F7DFD2", dark: "F0CBB5")

        static let danger = Color(light: "C0503F", dark: "E8756A")
        static let warning = Color(hex: "FFB347")
        static let success = Color(hex: "4CAF50")
        static let info = Color(hex: "00BCD4")
        static let purple = Color(hex: "9C27B0")
        static let pink = Color(hex: "E91E63")
        static let indigo = Color(hex: "3F51B5")

        static let textPrimary = Color(light: "2A2320", dark: "F4EEE7")
        static let textSecondary = Color(light: "8A7B6D", dark: "A79A8B")
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
            "C96F4A", "7D8F69", "C25B4E", "6B7FA3", "8E6B9E", "B08D57", "5F8A8B", "C2703C",
        ]
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        /// Gap above a section header — the largest vertical break in a scroll view.
        static let xxxl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 18
        static let control: CGFloat = 12
        static let hero: CGFloat = 20
        /// Rounded square behind a menu SF Symbol.
        static let icon: CGFloat = 11
        /// Fully rounded — chips, pills, capsule buttons.
        static let pill: CGFloat = 999
    }

    /// App typography. Uses IBM Plex Sans Thai when the `.ttf` files are bundled
    /// (see `UIAppFonts` in Info.plist) and falls back to the system font
    /// automatically when they're missing, so the app never fails to render.
    enum Font {
        private static let regularName = "IBMPlexSansThai-Regular"
        private static let mediumName = "IBMPlexSansThai-Medium"
        private static let semiBoldName = "IBMPlexSansThai-SemiBold"

        /// Resolved once — the font files either shipped in the bundle or they didn't.
        private static let isBundled: Bool = {
            let found = UIFont(name: regularName, size: 12) != nil
            if found {
                AppLog.action("Theme", "IBM Plex Sans Thai พร้อมใช้งาน")
            } else {
                AppLog.warn("Theme", "ไม่พบ IBM Plex Sans Thai — ใช้ฟอนต์ระบบแทน (ดู UIAppFonts ใน Info.plist)")
            }
            return found
        }()

        private static func name(for weight: SwiftUI.Font.Weight) -> String {
            switch weight {
            case .semibold, .bold, .heavy, .black: return semiBoldName
            case .medium: return mediumName
            default: return regularName
            }
        }

        /// Base builder — prefer the named tokens below; use this only for one-offs.
        static func plex(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            isBundled
                ? .custom(name(for: weight), size: size)
                : .system(size: size, weight: weight)
        }

        static let title = plex(24, .semibold)
        static let heading = plex(19, .semibold)
        static let body = plex(15)
        static let label = plex(13)
        static let caption = plex(11)

        /// Large figures (GPAX, countdowns, counters) — monospaced digits keep the
        /// layout from jittering while `.contentTransition(.numericText())` animates.
        static func number(_ size: CGFloat = 24) -> SwiftUI.Font {
            plex(size, .semibold).monospacedDigit()
        }
    }
}

/// Reusable card container matching the Dashboard's visual style.
struct CardContainer<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme

    // Spelled out rather than left to the memberwise initializer: 28 call sites
    // across the app construct this, and a synthesized init is easy to break by
    // adding a stored property in the wrong place.
    init(padding: CGFloat = Theme.Spacing.lg, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            content
        }
        .padding(padding)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.cardStroke, lineWidth: 1)
        )
        // A black shadow on a near-black background is invisible — in dark mode the
        // `cardStroke` border carries the edge on its own.
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0 : 0.05),
            radius: 10, x: 0, y: 3
        )
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

/// Shared "press to shrink slightly" feedback for tappable tiles and cards.
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
