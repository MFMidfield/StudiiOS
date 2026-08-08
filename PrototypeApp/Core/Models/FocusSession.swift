//
//  FocusSession.swift
//  Records completed Pomodoro/focus timer sessions for Reading Statistics.
//
//  `kindRaw` / `endedAt` / `wasLocked` were added later — every new property
//  carries a default so SwiftData can migrate existing stores in place.
//

import Foundation
import SwiftData

/// ประเภทของช่วงเวลาใน 1 รอบ Pomodoro
enum PomodoroPhase: String, Codable, CaseIterable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .focus:      return "โฟกัส"
        case .shortBreak: return "พักสั้น"
        case .longBreak:  return "พักยาว"
        }
    }

    var isBreak: Bool { self != .focus }

    /// ข้อความแจ้งเตือนตอน "ช่วงนี้" หมดเวลา
    var endedNotificationTitle: String {
        switch self {
        case .focus:      return "หมดเวลาโฟกัส 🎉"
        case .shortBreak: return "หมดเวลาพัก"
        case .longBreak:  return "หมดเวลาพักยาว"
        }
    }
}

@Model
final class FocusSession {
    var startedAt: Date
    var durationSeconds: Int
    var completed: Bool

    /// เก็บเป็น String เพราะ SwiftData เก็บ enum ตรงๆ ไม่ได้ — อ่านผ่าน `phase`
    var kindRaw: String = PomodoroPhase.focus.rawValue

    /// เวลาที่จบจริง (nil = ข้อมูลเก่าก่อนมีฟิลด์นี้)
    var endedAt: Date?

    /// เซสชันนี้เปิดโหมดล็อกแอปไว้ไหม — ใช้โชว์ในสถิติ
    var wasLocked: Bool = false

    var phase: PomodoroPhase {
        get { PomodoroPhase(rawValue: kindRaw) ?? .focus }
        set { kindRaw = newValue.rawValue }
    }

    init(
        startedAt: Date = .now,
        durationSeconds: Int,
        completed: Bool = true,
        phase: PomodoroPhase = .focus,
        endedAt: Date? = nil,
        wasLocked: Bool = false
    ) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.kindRaw = phase.rawValue
        self.endedAt = endedAt
        self.wasLocked = wasLocked
    }
}
