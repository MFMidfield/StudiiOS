//
//  OnboardingFlowView.swift
//  The whole setup flow: one NavigationStack, one step enum, one exit.
//
//  Every screen is pushed onto `path`, so the system's own back gesture works and
//  a screen never has to know what comes before it. Screens move forward by
//  calling `advance()`; only the last screen finishes the flow, via
//  OnboardingGate.complete() — RootContainerView is watching that key.
//
//  The current step is written to OnboardingGate on every change, so force-quitting
//  halfway through resumes where the student left off instead of starting over.
//

import SwiftUI

struct OnboardingFlowView: View {
    /// Only the debug replay passes this — the real flow needs nothing here,
    /// RootContainerView swaps itself out when OnboardingGate.complete() lands.
    var onFinished: (() -> Void)?

    @State private var path: [OnboardingStep] = []

    private var current: OnboardingStep { path.last ?? .intro }

    var body: some View {
        NavigationStack(path: $path) {
            page(for: .intro)
                .navigationDestination(for: OnboardingStep.self) { step in
                    page(for: step)
                }
        }
        .tint(Theme.Colors.primaryDeep)
        .onAppear(perform: restoreSavedStep)
        .onChange(of: current) { _, step in
            OnboardingGate.save(step: step)
        }
    }

    // MARK: - Routing

    @ViewBuilder
    private func page(for step: OnboardingStep) -> some View {
        switch step {
        case .intro:
            OnboardingIntroView { advance(to: .profile) }
        case .profile:
            ProfileSetupView(onBack: goBack) { advance(to: .schedule) }
        case .schedule:
            // เพิ่งขึ้น ม.4 เทอม 1 = ไม่มีเทอมย้อนหลังให้กรอก ข้ามไปเลยตั้งแต่ตอนกด
            // ไม่ใช่เข้าหน้านั้นแล้วเด้งออก (เด้งออกเอง = ปัดย้อนกลับมาไม่ได้อีก)
            ScheduleSetupView(onBack: goBack) {
                advance(to: GradeBacklogSetupView.hasBacklog ? .grades : .portfolio)
            }
        case .grades:
            GradeBacklogSetupView(onBack: goBack) { advance(to: .portfolio) }
        case .portfolio:
            PortfolioSetupView(onBack: goBack) { advance(to: .permissions) }
        case .permissions:
            PermissionsSetupView(onBack: goBack, onFinish: finish)
        }
    }

    private func advance(to step: OnboardingStep) {
        withAnimation { path.append(step) }
    }

    private func goBack() {
        guard !path.isEmpty else { return }
        withAnimation { _ = path.removeLast() }
    }

    private func finish() {
        OnboardingGate.complete()
        onFinished?()
    }

    /// Rebuilds the stack up to the step we stopped on, so back still works after
    /// a relaunch. `.intro` is the root and never sits in `path`.
    private func restoreSavedStep() {
        guard path.isEmpty else { return }
        let saved = OnboardingGate.savedStep
        guard saved != .intro else { return }
        path = OnboardingStep.allCases.filter { $0 != .intro && $0.rawValue <= saved.rawValue }
    }
}

#Preview {
    OnboardingFlowView()
}
