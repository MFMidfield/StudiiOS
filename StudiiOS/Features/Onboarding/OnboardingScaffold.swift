//
//  OnboardingScaffold.swift
//  The frame every setup screen sits in: back arrow + progress, title block,
//  scrolling content, and a pinned action bar at the bottom.
//
//  Screens only describe their own content and what the buttons say. Spacing,
//  progress and the button treatment live here so all six screens stay identical
//  down to the pixel — the old wizard drifted because each screen rebuilt this.
//

import SwiftUI

struct OnboardingScaffold<Content: View>: View {
    let step: OnboardingStep

    /// nil = no way back (the first screen, or a screen that already committed).
    var onBack: (() -> Void)?

    var primaryTitle: String = "ถัดไป"
    var isPrimaryEnabled: Bool = true
    /// The quieter button under the primary one — "ข้าม" and friends.
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?

    let onPrimary: () -> Void

    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                content
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
            actionBar
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Hiding the bar takes the edge swipe with it — put it back.
        .interactiveSwipeBack()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.md) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primaryDeep)
                            .frame(width: 36, height: 36)
                            .background(Theme.Colors.primarySoft, in: Circle())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("ย้อนกลับ")
                }

                if step.showsProgress {
                    progressBar
                    Text("\(step.number)/\(OnboardingStep.count)")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(step.title)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(step.subtitle)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private var progressBar: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(OnboardingStep.allCases) { other in
                Capsule()
                    .fill(other.rawValue <= step.rawValue
                          ? Theme.Colors.primary
                          : Theme.Colors.primarySoft)
                    .frame(height: 5)
            }
        }
        .animation(.easeOut(duration: 0.25), value: step)
        .accessibilityLabel("ขั้นที่ \(step.number) จาก \(OnboardingStep.count)")
    }

    // MARK: - Bottom

    private var actionBar: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(Theme.Font.plex(16, .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(isPrimaryEnabled ? Theme.Colors.primary : Theme.Colors.primary.opacity(0.35))
                    .foregroundStyle(Theme.Colors.onPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!isPrimaryEnabled)

            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle, action: onSecondary)
                    .font(Theme.Font.plex(14, .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.lg)
        .background(
            Theme.Colors.background
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.Colors.separator)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    OnboardingScaffold(
        step: .profile,
        onBack: {},
        primaryTitle: "ถัดไป",
        secondaryTitle: "ข้ามไปก่อน",
        onSecondary: {},
        onPrimary: {}
    ) {
        CardContainer {
            Text("เนื้อหาของหน้า")
                .font(Theme.Font.body)
        }
    }
}
