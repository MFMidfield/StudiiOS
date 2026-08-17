//
//  PomodoroSettings.swift
//  ค่าตั้งของโหมดโฟกัส — จุดเดียวที่รู้จัก key ของ UserDefaults
//
//  ทั้ง View และ PomodoroEngine อ่านผ่านที่นี่ ห้ามเขียน UserDefaults key ตรงๆ ที่อื่น
//
//  **โละหน้า "ตั้งค่า Pomodoro" ทิ้งแล้ว (15 ส.ค. 2569)** — key ที่หายไปคือ
//  `pomodoroShortBreakMinutes` · `pomodoroLongBreakMinutes` ·
//  `pomodoroRoundsBeforeLongBreak` · `pomodoroAutoContinue`
//  ตอนนี้ช่วงพัก **คงที่ 5 นาที** ผู้ใช้เลือกไม่ได้ และไม่มีพักยาว/นับรอบอีกแล้ว
//

import Foundation

enum PomodoroSettings {
    // MARK: - Keys

    enum Key {
        /// ความยาวรอบโฟกัสล่าสุดที่ผู้ใช้เลือก — **`0` = โหมด ∞ (นับขึ้น)**
        static let focusMinutes     = "pomodoroFocusMinutes"
        static let blockAppsEnabled = "pomodoroBlockAppsEnabled"
        /// `FocusTag.id` ที่เลือกไว้ล่าสุด — ว่าง = ไม่ได้เลือกแท็ก
        static let selectedTagID    = "focusSelectedTagID"
    }

    // MARK: - ขอบเขตที่ยอมรับ

    /// ค่าที่เลือกได้บนไม้บรรทัด: `0` (∞) แล้วต่อด้วย 1…180 ทีละ 1 นาที
    static let minuteRange = 0...180
    static let maxMinutes = 180

    /// ช่วงพักคงที่ ผู้ใช้เปลี่ยนไม่ได้
    static let breakMinutes = 5

    /// โหมด ∞ ทำได้อย่างน้อยเท่านี้ถึงจะนับว่า "สำเร็จ" ในสถิติ
    static let countUpSuccessSeconds = 10 * 60

    /// ต่ำกว่านี้ไม่บันทึกลงสถิติเลย (กันกดเริ่มแล้วกดหยุดทันที)
    static let minimumRecordedSeconds = 60

    // MARK: - ค่าเริ่มต้น

    static let defaultFocusMinutes = 25

    // MARK: - อ่านค่าปัจจุบัน (ใช้โดย Engine ที่ไม่มี @AppStorage)

    /// `0` = ∞ · ค่านอกช่วงถือว่าเสีย → คืนค่าเริ่มต้น
    static var focusMinutes: Int {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Key.focusMinutes) != nil else { return defaultFocusMinutes }
        let stored = defaults.integer(forKey: Key.focusMinutes)
        return minuteRange.contains(stored) ? stored : defaultFocusMinutes
    }

    /// บล็อกแอปอื่นด้วย Screen Time API ตอนโฟกัส (ค่าเริ่มต้น = ปิด — ต้องขออนุญาตก่อน)
    static var blockAppsEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.blockAppsEnabled) as? Bool ?? false
    }

    /// ความยาวเป็นวินาทีของแต่ละช่วง — ช่วงพักทั้งสองแบบยาวเท่ากันหมดแล้ว
    static func duration(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus:                 return max(1, focusMinutes) * 60
        case .shortBreak, .longBreak: return breakMinutes * 60
        }
    }
}
