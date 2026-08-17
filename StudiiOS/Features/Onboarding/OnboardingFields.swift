//
//  OnboardingFields.swift
//  The two input shapes the setup screens use: a labelled text field and a row
//  of choice chips.
//
//  Setup deliberately does not use `Form`. A Form on a full-bleed screen brings
//  its own background, insets and section styling, none of which match the rest of
//  the app — the old wizard looked like Settings by accident. These build the same
//  controls out of Theme tokens instead.
//

import SwiftUI

// MARK: - Text field

struct OnboardingTextField: View {
    let title: String
    var placeholder: String = ""
    /// "ไม่บังคับ" appears next to the label; nothing enforces it here.
    var isOptional: Bool = false
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                if isOptional {
                    Text("ไม่บังคับ")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
                }
            }
            TextField(placeholder.isEmpty ? title : placeholder, text: $text)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
    }
}

// MARK: - Chips

/// A single row of mutually exclusive choices. Wraps onto more lines when the
/// labels are long (แผนการเรียน), stays on one line when they are short (ม.4/5/6).
struct OnboardingChipRow<Value: Hashable>: View {
    let title: String
    var footnote: String?
    let values: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)

            // FlowLayout-free wrapping: a LazyVGrid with adaptive columns keeps
            // chips their natural width and drops the overflow onto a new line.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.sm)],
                      alignment: .leading,
                      spacing: Theme.Spacing.sm) {
                ForEach(values, id: \.self) { value in
                    chip(value)
                }
            }

            if let footnote {
                Text(footnote)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func chip(_ value: Value) -> some View {
        let isSelected = selection == value
        return Button {
            selection = value
        } label: {
            Text(label(value))
                .font(Theme.Font.plex(14, .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(isSelected ? Theme.Colors.primary : Theme.Colors.surfaceRaised)
                .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Section

/// A titled block inside a setup screen. Same visual weight as `SectionHeader`
/// on the main screens, without that view's trailing-action plumbing.
struct OnboardingSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(Theme.Font.plex(13, .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .textCase(nil)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
