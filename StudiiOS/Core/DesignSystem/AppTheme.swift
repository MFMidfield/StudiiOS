//
//  AppTheme.swift
//  สว่าง / มืด / ตามระบบ — the one place that knows the theme preference key.
//
//  Read in exactly two places: the picker in SettingsView, and
//  `.preferredColorScheme` on RootContainerView. Every colour token in
//  Theme.swift is already `Color(light:dark:)`, so nothing else has to react.
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    /// The single UserDefaults key. Anything reading the theme goes through
    /// `@AppStorage(AppTheme.storageKey)`, never a raw string.
    static let storageKey = "com.studentos.appTheme"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "ตามระบบ"
        case .light: return "สว่าง"
        case .dark: return "มืด"
        }
    }

    /// nil hands control back to iOS — that is what "ตามระบบ" means.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
