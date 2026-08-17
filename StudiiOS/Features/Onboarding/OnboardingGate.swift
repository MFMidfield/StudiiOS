//
//  OnboardingGate.swift
//  The only place that knows whether setup is done and how far it got.
//
//  Replaces the five loose @AppStorage("hasCompleted…") booleans the old wizard
//  used. Those keys still exist on devices that finished the old flow, so
//  `migrateLegacyIfNeeded()` reads them once and marks setup complete — a student
//  who already set the app up must never be dropped back into onboarding.
//
//  Nothing else may read or write these keys. Add a step = add a case in
//  OnboardingStep, not another boolean.
//

import Foundation

// MARK: - Step

/// The six screens of setup, in order. `rawValue` is what gets persisted, so
/// never renumber existing cases — append instead.
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case intro = 0
    case profile
    case schedule
    case grades
    case portfolio
    /// แทรก 16 ส.ค. 2569 — `permissions` เลื่อนจาก 5 เป็น 6 (เครื่องที่ค้างกลาง setup
    /// ที่ step 5 พอดีจะไปโผล่หน้า SOP แทนหน้าสิทธิ์ ครั้งเดียว)
    case sop
    case permissions

    var id: Int { rawValue }

    /// 1-based position for "ขั้นที่ 3 จาก 6".
    var number: Int { rawValue + 1 }

    static var count: Int { allCases.count }

    var title: String {
        switch self {
        case .intro:       return "ยินดีต้อนรับ"
        case .profile:     return "ข้อมูลของคุณ"
        case .schedule:    return "ตารางเรียน"
        case .grades:      return "เกรดที่ผ่านมา"
        case .portfolio:   return "ผลงานของคุณ"
        case .sop:         return "SOP"
        case .permissions: return "พร้อมใช้งานแล้ว"
        }
    }

    var subtitle: String {
        switch self {
        case .intro:       return "แอปเดียวที่ดูแลทั้งการเรียน เกรด และเส้นทางต่อมหาวิทยาลัย"
        case .profile:     return "ใช้เรียกชื่อคุณ และผูกกับระบบเกรดให้ถูกเทอม"
        case .schedule:    return "ถ่ายรูปตารางจากโรงเรียน หรือกรอกเองก็ได้"
        case .grades:      return "กรอกไว้เพื่อให้แอปคำนวณ GPAX ให้ตรงความจริง"
        case .portfolio:   return "เก็บเกียรติบัตรและกิจกรรมไว้ตั้งแต่วันนี้"
        case .sop:         return "ใส่คณะที่อยากยื่น แล้วเริ่มร่าง SOP ได้เลย"
        case .permissions: return "เปิดสิทธิ์ที่ต้องใช้ แล้วเริ่มได้เลย"
        }
    }

    /// The intro carries no progress bar — it is the cover, not a step.
    var showsProgress: Bool { self != .intro }
}

// MARK: - Gate

enum OnboardingGate {

    enum Key {
        static let completed = "com.studentos.onboarding.completed"
        static let step = "com.studentos.onboarding.step"
    }

    /// Keys written by the wizard this flow replaces. Read once by
    /// `migrateLegacyIfNeeded()`, then cleared. Do not use them anywhere else.
    private enum LegacyKey {
        static let onboarding = "hasCompletedOnboarding"
        static let profile = "hasCompletedProfileSetup"
        static let schedule = "hasCompletedScheduleSetup"
        static let grade = "hasCompletedGradeSetup"
        static let summary = "hasCompletedSetupSummary"

        static let all = [onboarding, profile, schedule, grade, summary]
    }

    // MARK: Reading

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: Key.completed)
    }

    /// Where to resume after a force-quit halfway through setup.
    static var savedStep: OnboardingStep {
        OnboardingStep(rawValue: UserDefaults.standard.integer(forKey: Key.step)) ?? .intro
    }

    // MARK: Writing

    static func save(step: OnboardingStep) {
        UserDefaults.standard.set(step.rawValue, forKey: Key.step)
    }

    static func complete() {
        UserDefaults.standard.set(true, forKey: Key.completed)
        AppLog.action("Onboarding", "จบขั้นตอนเริ่มต้นใช้งาน")
    }

    /// Called from `SettingsView.resetAllData()` — wiping the student's data has
    /// to send them back through setup, otherwise the app opens on an empty
    /// dashboard with no way to enter a term again.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: Key.completed)
        UserDefaults.standard.removeObject(forKey: Key.step)
    }

    // MARK: Debug replay

    #if DEBUG
    /// Debug-only: shows the flow again as the app's root, exactly where a new
    /// student sees it.
    ///
    /// It used to be presented in a fullScreenCover from Settings, which is a
    /// different code path: SettingsView rebuilds itself whenever notification
    /// state changes, and every rebuild tore down the cover's content — sheets
    /// opened from inside it closed themselves a frame later. Testing has to run
    /// on the real path or it tests the wrapper instead.
    static let replayKey = "com.studentos.onboarding.debugReplay"

    /// อ่านผ่าน `@AppStorage(OnboardingGate.replayKey)` ใน RootContainerView —
    /// จบ flow เมื่อไรถึงจะออก ไม่มีปุ่มปิดกลางทาง (Few ตัดออก 15 ส.ค.)
    static func startReplay() { UserDefaults.standard.set(true, forKey: replayKey) }

    static func endReplay() { UserDefaults.standard.removeObject(forKey: replayKey) }
    #endif

    // MARK: Migration

    /// Runs on every launch; does something exactly once. A device that reached
    /// the old summary screen is treated as fully set up, whatever the new flow
    /// asks for. Half-finished old runs (profile done, schedule not) start the
    /// new flow from the top — their answers are still in UserDefaults and the
    /// new screens prefill from them.
    static func migrateLegacyIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Key.completed) == nil else { return }

        let finishedOldFlow = defaults.bool(forKey: LegacyKey.summary)
        if finishedOldFlow {
            defaults.set(true, forKey: Key.completed)
            AppLog.action("Onboarding", "ผู้ใช้เดิมเคยตั้งค่าครบแล้ว — ข้ามขั้นตอนใหม่")
        }
        LegacyKey.all.forEach { defaults.removeObject(forKey: $0) }
    }
}
