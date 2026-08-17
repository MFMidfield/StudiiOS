//
//  GPAXSettings.swift
//  ค่าตั้งของ GPAX — จุดเดียวที่รู้จัก UserDefaults key พวกนี้ ห้ามเขียน key ตรงๆ ที่อื่น
//
//  currentGradeLevel/currentTermNumber คือเทอม "จริง" ของนักเรียน (D7) — คนละตัวกับ
//  TermStore.activeTermKey ซึ่งเป็นแค่เทอมที่กำลังเปิดดู ห้ามใช้แทนกัน
//

import Foundation

enum GPAXSettings {
    enum Key {
        static let currentGradeLevel = "com.studentos.gpax.currentGradeLevel"
        static let currentTermNumber = "com.studentos.gpax.currentTermNumber"
        static let target = "com.studentos.gpax.target"
        static let targetSource = "com.studentos.gpax.targetSource"
        static let entryMode = "com.studentos.gpax.entryMode"
        static let priorGPAX = "com.studentos.gpax.priorGPAX"
        static let priorCredits = "com.studentos.gpax.priorCredits"
        static let priorTermCount = "com.studentos.gpax.priorTermCount"
    }

    enum EntryMode: String {
        case perTerm
        case cumulative
    }

    // MARK: - เทอมจริงของนักเรียน (D7)

    /// ม.4–ม.6 เท่านั้น — แอปเลิกรับ ม.ต้นแล้ว (GPAX ของ TCAS นับเฉพาะ ม.ปลายอยู่แล้ว)
    /// เครื่องที่เคยตั้ง ม.1–ม.3 ไว้จะได้ nil = "ยังไม่ตั้งเทอมจริง" แล้วถูกถามใหม่
    static var currentGradeLevel: Int? {
        let stored = UserDefaults.standard.integer(forKey: Key.currentGradeLevel)
        return SchoolBand.upper.gradeLevels.contains(stored) ? stored : nil
    }

    static var currentTermNumber: Int? {
        let stored = UserDefaults.standard.integer(forKey: Key.currentTermNumber)
        return (1...2).contains(stored) ? stored : nil
    }

    /// nil = ยังไม่เคยผ่านหน้าเลือกระดับชั้น (Screen 1)
    static var currentSortKey: Int? {
        guard let level = currentGradeLevel, let term = currentTermNumber else { return nil }
        return level * 10 + term
    }

    static func setCurrentTerm(gradeLevel: Int, termNumber: Int) {
        UserDefaults.standard.set(gradeLevel, forKey: Key.currentGradeLevel)
        UserDefaults.standard.set(termNumber, forKey: Key.currentTermNumber)
        GPAXStore.shared.bump()
    }

    // MARK: - เป้า GPAX

    /// 0 = ยังไม่ตั้งเป้า
    static var target: Double {
        UserDefaults.standard.double(forKey: Key.target)
    }

    static var hasTarget: Bool { target > 0 }

    static var targetSource: String {
        UserDefaults.standard.string(forKey: Key.targetSource) ?? ""
    }

    static func setTarget(_ value: Double, source: String) {
        UserDefaults.standard.set(value, forKey: Key.target)
        UserDefaults.standard.set(source, forKey: Key.targetSource)
        GPAXStore.shared.bump()
    }

    // MARK: - โหมดกรอก (D3/D4)

    static var entryMode: EntryMode {
        EntryMode(rawValue: UserDefaults.standard.string(forKey: Key.entryMode) ?? "") ?? .perTerm
    }

    static func setEntryMode(_ mode: EntryMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: Key.entryMode)
        GPAXStore.shared.bump()
    }

    static var priorGPAX: Double {
        UserDefaults.standard.double(forKey: Key.priorGPAX)
    }

    static var priorTermCount: Int {
        UserDefaults.standard.integer(forKey: Key.priorTermCount)
    }

    static var priorCredits: Double {
        let stored = UserDefaults.standard.double(forKey: Key.priorCredits)
        return stored > 0 ? stored : Double(priorTermCount) * GPAXCalculator.defaultTermCredits
    }

    static func setCumulative(gpax: Double, credits: Double?, termCount: Int) {
        UserDefaults.standard.set(gpax, forKey: Key.priorGPAX)
        UserDefaults.standard.set(termCount, forKey: Key.priorTermCount)
        if let credits {
            UserDefaults.standard.set(credits, forKey: Key.priorCredits)
        }
        GPAXStore.shared.bump()
    }

    /// nil เมื่อไม่ได้อยู่โหมดสะสม หรือยังไม่เคยกรอกตัวเลข — ใช้ส่งตรงเข้า
    /// `GPAXCalculator.calculate(cumulative:)`
    static var cumulativeOverride: GPAXCalculator.CumulativeOverride? {
        guard entryMode == .cumulative, priorGPAX > 0 else { return nil }
        return GPAXCalculator.CumulativeOverride(gpax: priorGPAX, credits: priorCredits)
    }

    // MARK: - ล้างข้อมูล

    /// ล้างค่า GPAX ทั้งหมด — ใช้โดย `SettingsView.resetAllData()` เท่านั้น
    ///
    /// ต้องอยู่ในไฟล์นี้เพราะนี่คือจุดเดียวที่รู้จัก UserDefaults key ของ GPAX
    /// ถ้าไปเขียน `removeObject` ตรงๆ ที่ SettingsView จะมีสองที่ที่รู้จัก key
    /// แล้วเพี้ยนกันเงียบๆ ตอนมีใครเพิ่ม key ใหม่
    ///
    /// ⚠️ เพิ่ม `Key` ใหม่เมื่อไร ต้องมาเพิ่มในลิสต์นี้ด้วย ไม่งั้นลบข้อมูลแล้วค่าจะค้าง
    static func resetAll() {
        let keys = [
            Key.currentGradeLevel,
            Key.currentTermNumber,
            Key.target,
            Key.targetSource,
            Key.entryMode,
            Key.priorGPAX,
            Key.priorCredits,
            Key.priorTermCount,
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        GPAXStore.shared.bump()
    }
}
