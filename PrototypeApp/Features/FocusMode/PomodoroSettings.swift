//
//  PomodoroSettings.swift
//  ค่าตั้งของ Pomodoro — จุดเดียวที่รู้จัก key ของ UserDefaults
//
//  ทั้ง View และ PomodoroEngine อ่านผ่านที่นี่ ห้ามเขียน UserDefaults key ตรงๆ ที่อื่น
//

import Foundation

enum PomodoroSettings {
    // MARK: - Keys

    enum Key {
        static let focusMinutes      = "pomodoroFocusMinutes"
        static let shortBreakMinutes = "pomodoroShortBreakMinutes"
        static let longBreakMinutes  = "pomodoroLongBreakMinutes"
        static let roundsBeforeLong  = "pomodoroRoundsBeforeLongBreak"
        static let autoContinue      = "pomodoroAutoContinue"
        static let lockEnabled       = "pomodoroLockEnabled"
        static let blockAppsEnabled  = "pomodoroBlockAppsEnabled"
    }

    // MARK: - ขอบเขตที่ยอมรับ

    static let minuteRange = 1...180
    static let focusPresets = [15, 25, 30, 50]
    static let breakPresets = [3, 5, 10, 15]

    // MARK: - ค่าเริ่มต้น

    static let defaultFocusMinutes = 25
    static let defaultShortBreakMinutes = 5
    static let defaultLongBreakMinutes = 15
    static let defaultRoundsBeforeLongBreak = 4

    // MARK: - อ่านค่าปัจจุบัน (ใช้โดย Engine ที่ไม่มี @AppStorage)

    private static func int(_ key: String, default fallback: Int) -> Int {
        let stored = UserDefaults.standard.integer(forKey: key)
        guard minuteRange.contains(stored) else { return fallback }
        return stored
    }

    static var focusMinutes: Int { int(Key.focusMinutes, default: defaultFocusMinutes) }
    static var shortBreakMinutes: Int { int(Key.shortBreakMinutes, default: defaultShortBreakMinutes) }
    static var longBreakMinutes: Int { int(Key.longBreakMinutes, default: defaultLongBreakMinutes) }

    static var roundsBeforeLongBreak: Int {
        let stored = UserDefaults.standard.integer(forKey: Key.roundsBeforeLong)
        return (2...8).contains(stored) ? stored : defaultRoundsBeforeLongBreak
    }

    /// ไปช่วงถัดไปเองโดยไม่ต้องกดเริ่มใหม่ (ค่าเริ่มต้น = เปิด)
    static var autoContinue: Bool {
        UserDefaults.standard.object(forKey: Key.autoContinue) as? Bool ?? true
    }

    /// เปิดหน้าจอล็อกเต็มจอตอนโฟกัส (ค่าเริ่มต้น = เปิด)
    static var lockEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.lockEnabled) as? Bool ?? true
    }

    /// บล็อกแอปอื่นด้วย Screen Time API ตอนโฟกัส (ค่าเริ่มต้น = ปิด — ต้องขออนุญาตก่อน)
    static var blockAppsEnabled: Bool {
        UserDefaults.standard.object(forKey: Key.blockAppsEnabled) as? Bool ?? false
    }

    /// ความยาวเป็นวินาทีของแต่ละช่วง
    static func duration(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus:      return focusMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak:  return longBreakMinutes * 60
        }
    }
}
