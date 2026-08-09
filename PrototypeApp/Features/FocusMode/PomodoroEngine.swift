//
//  PomodoroEngine.swift
//  หัวใจของโหมดโฟกัส — จุดเดียวที่รู้ว่า "ตอนนี้เหลือกี่วินาที"
//
//  หลักการสำคัญ: **นับจาก deadline (Date) ไม่ใช่นับ tick**
//  ของเดิมใช้ `secondsRemaining -= 1` ทุกวินาที ซึ่งพังทันทีที่แอปเข้า background
//  (Timer หยุด → เวลาค้าง) เวอร์ชันนี้เก็บ `deadline: Date` แล้วคำนวณ
//  `deadline.timeIntervalSinceNow` ทุกครั้งที่วาด → ปิดจอ/สลับแอป/บังคับปิดแอป
//  แล้วกลับมา เวลาก็ยังถูก
//
//  สถานะทั้งหมดถูก mirror ลง UserDefaults เพื่อให้กู้กลับได้หลัง force-quit —
//  จำเป็นมาก เพราะโหมดบล็อกแอปเป็นการตั้งค่าระดับ**ระบบ** ถ้ากู้สถานะไม่ได้
//  แอปที่ถูกบล็อกจะค้างบล็อกตลอดไป
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class PomodoroEngine {

    static let shared = PomodoroEngine()

    // MARK: - สถานะที่ View อ่าน

    private(set) var phase: PomodoroPhase = .focus
    /// เวลาที่ช่วงปัจจุบันจะหมด — nil = ไม่ได้กำลังเดิน
    private(set) var deadline: Date?
    /// วินาทีที่ค้างไว้ตอนกดหยุดชั่วคราว — nil = ไม่ได้พัก
    private(set) var pausedRemaining: Int?
    /// ความยาวเต็มของช่วงปัจจุบัน (วินาที) ใช้คำนวณวงแหวนความคืบหน้า
    private(set) var plannedDuration: Int = PomodoroSettings.defaultFocusMinutes * 60
    /// จำนวนรอบโฟกัสที่ทำจบไปแล้วในชุดนี้
    private(set) var completedFocusRounds: Int = 0
    /// เวลาที่ช่วงปัจจุบันเริ่ม
    private(set) var phaseStartedAt: Date = .now

    /// ตัวขับการวาดใหม่ — เปลี่ยนทุก 0.5 วิ ให้ View คำนวณ remaining ใหม่
    private(set) var tickToken: Int = 0

    // MARK: - สถานะภายใน

    private var ticker: Timer?
    private var context: ModelContext?

    /// ถ้ากลับมาช้ากว่านี้หลังหมดเวลา ถือว่าเลิกรอบ ไม่ไล่ช่วงถัดไปให้
    /// (กันกรณีปิดแอปทิ้ง 3 ชั่วโมงแล้วโดนสร้างเซสชันปลอมสิบกว่าอัน)
    private let autoAdvanceGrace: TimeInterval = 5 * 60

    private init() {
        restore()
    }

    // MARK: - ค่าที่คำนวณให้ View

    var isRunning: Bool { deadline != nil }
    var isPaused: Bool { pausedRemaining != nil }
    var isIdle: Bool { deadline == nil && pausedRemaining == nil }

    /// วินาทีที่เหลือ — คำนวณสดจากนาฬิกาจริงทุกครั้ง
    var secondsRemaining: Int {
        if let paused = pausedRemaining { return paused }
        guard let deadline else { return plannedDuration }
        return max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        return 1 - Double(secondsRemaining) / Double(plannedDuration)
    }

    var timeString: String {
        let s = secondsRemaining
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// รอบถัดไปเป็นพักยาวไหม
    var nextPhaseAfterFocus: PomodoroPhase {
        let rounds = PomodoroSettings.roundsBeforeLongBreak
        return (completedFocusRounds + 1) % rounds == 0 ? .longBreak : .shortBreak
    }

    // MARK: - ผูก SwiftData

    /// เรียกจาก `.task` ของ FocusModeView — ต้องมีก่อนถึงจะบันทึกสถิติได้
    func attach(context: ModelContext) {
        self.context = context
    }

    // MARK: - คำสั่งหลัก

    /// เริ่มช่วงโฟกัสใหม่ตั้งแต่ต้น
    /// - Parameter minutes: ความยาว (นาที) — ถ้า nil ใช้ค่าจากการตั้งค่า
    func startFocus(minutes: Int? = nil) {
        let seconds = (minutes ?? PomodoroSettings.focusMinutes) * 60
        completedFocusRounds = 0
        begin(phase: .focus, seconds: seconds, at: .now)
    }

    func pause() {
        guard let deadline else { return }
        pausedRemaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
        self.deadline = nil
        stopTicker()
        Task { await NotificationManager.shared.cancelFocusNotification() }
        // ระหว่างพักชั่วคราว ปลดบล็อกแอปด้วย ไม่งั้นผู้ใช้ติดค้างโดยที่นาฬิกาไม่เดิน
        AppBlockManager.shared.stopBlocking(reason: "หยุดชั่วคราว")
        persist()
        AppLog.action("Pomodoro", "หยุดชั่วคราว เหลือ \(pausedRemaining ?? 0) วิ")
    }

    func resume() {
        guard let remaining = pausedRemaining else { return }
        pausedRemaining = nil
        deadline = Date.now.addingTimeInterval(TimeInterval(remaining))
        startTicker()
        scheduleEndNotification()
        applyBlockingIfNeeded()
        persist()
        AppLog.action("Pomodoro", "เริ่มต่อ เหลือ \(remaining) วิ")
    }

    /// จบทุกอย่าง — ใช้ทั้งตอนกด "ยอมแพ้" และตอนกดรีเซ็ต
    /// - Parameter recordPartial: บันทึกเวลาที่ทำไปแล้วเป็นเซสชันไม่สำเร็จไหม
    func stop(recordPartial: Bool = true) {
        if recordPartial, phase == .focus, !isIdle {
            let elapsed = plannedDuration - secondsRemaining
            if elapsed >= 60 {
                insertSession(phase: .focus, seconds: elapsed, completed: false, endedAt: .now)
            }
        }
        deadline = nil
        pausedRemaining = nil
        plannedDuration = PomodoroSettings.duration(for: .focus)
        phase = .focus
        stopTicker()
        Task { await NotificationManager.shared.cancelFocusNotification() }
        AppBlockManager.shared.stopBlocking(reason: "จบเซสชัน")
        persist()
        AppLog.action("Pomodoro", "หยุดเซสชัน")
    }

    /// ข้ามช่วงพักไปเริ่มโฟกัสรอบถัดไปเลย
    func skipBreak() {
        guard phase.isBreak else { return }
        insertSession(phase: phase, seconds: plannedDuration - secondsRemaining, completed: false, endedAt: .now)
        begin(phase: .focus, seconds: PomodoroSettings.duration(for: .focus), at: .now)
    }

    // MARK: - Life-cycle hooks (เรียกจาก View / RootContainerView)

    /// เรียกทุกครั้งที่แอปกลับมา active และตอนหน้าโฟกัสปรากฏ
    func syncToNow() {
        guard let deadline else { return }
        guard deadline <= .now else {
            // ยังไม่หมดเวลา — แค่ให้แน่ใจว่า ticker กับ shield ยังทำงาน
            startTicker()
            applyBlockingIfNeeded()
            return
        }

        let overdue = Date.now.timeIntervalSince(deadline)
        finishCurrentPhase(at: deadline)

        if PomodoroSettings.autoContinue, overdue <= autoAdvanceGrace {
            advanceAfterCompletion(startingAt: deadline)
        } else {
            // กลับมาช้าเกินไป หรือปิด auto — จบชุดนี้และปลดล็อกทุกอย่าง
            self.deadline = nil
            pausedRemaining = nil
            stopTicker()
            AppBlockManager.shared.stopBlocking(reason: "หมดเวลาแล้ว")
            persist()
        }
    }

    // MARK: - ภายใน

    private func begin(phase newPhase: PomodoroPhase, seconds: Int, at start: Date) {
        phase = newPhase
        plannedDuration = max(60, seconds)
        phaseStartedAt = start
        deadline = start.addingTimeInterval(TimeInterval(plannedDuration))
        pausedRemaining = nil

        startTicker()
        scheduleEndNotification()
        applyBlockingIfNeeded()
        persist()
        AppLog.action("Pomodoro", "เริ่ม \(newPhase.label) \(plannedDuration / 60) นาที")
    }

    /// บันทึกช่วงที่เพิ่งจบลง SwiftData
    private func finishCurrentPhase(at endedAt: Date) {
        insertSession(phase: phase, seconds: plannedDuration, completed: true, endedAt: endedAt)
        if phase == .focus {
            completedFocusRounds += 1
        }
    }

    /// เลือกช่วงถัดไปตามกติกา Pomodoro แล้วเริ่มต่อ
    private func advanceAfterCompletion(startingAt start: Date) {
        let next: PomodoroPhase
        if phase == .focus {
            let rounds = PomodoroSettings.roundsBeforeLongBreak
            next = completedFocusRounds % rounds == 0 ? .longBreak : .shortBreak
        } else {
            next = .focus
        }

        // ช่วงพักไม่บล็อกแอป — ผู้ใช้ควรได้พักจริง
        if next.isBreak {
            AppBlockManager.shared.stopBlocking(reason: "ถึงเวลาพัก")
        }

        begin(phase: next, seconds: PomodoroSettings.duration(for: next), at: start)
    }

    private func insertSession(phase: PomodoroPhase, seconds: Int, completed: Bool, endedAt: Date) {
        guard let context, seconds > 0 else { return }
        let session = FocusSession(
            startedAt: endedAt.addingTimeInterval(-TimeInterval(seconds)),
            durationSeconds: seconds,
            completed: completed,
            phase: phase,
            endedAt: endedAt,
            wasLocked: PomodoroSettings.blockAppsEnabled
        )
        context.insert(session)
        try? context.save()
    }

    private func applyBlockingIfNeeded() {
        guard phase == .focus, let deadline, PomodoroSettings.blockAppsEnabled else { return }
        AppBlockManager.shared.startBlocking(until: deadline)
    }

    private func scheduleEndNotification() {
        guard let deadline else { return }
        let endingPhase = phase
        let nextLabel: String
        if PomodoroSettings.autoContinue {
            if endingPhase == .focus {
                nextLabel = "เริ่ม\(nextPhaseAfterFocus.label)แล้ว"
            } else {
                nextLabel = "กลับมาโฟกัสต่อได้เลย"
            }
        } else {
            nextLabel = "เปิดแอปเพื่อเริ่มช่วงถัดไป"
        }
        Task {
            await NotificationManager.shared.scheduleFocusEnd(
                at: deadline,
                phase: endingPhase,
                body: nextLabel
            )
        }
    }

    // MARK: - Ticker (ใช้แค่กระตุ้นให้ View วาดใหม่ ไม่ได้ใช้นับเวลา)

    private func startTicker() {
        guard ticker == nil, deadline != nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        tickToken &+= 1
        guard let deadline, deadline <= .now else { return }
        syncToNow()
    }

    // MARK: - กู้สถานะหลัง force-quit

    private enum Store {
        static let phase = "pomodoroStatePhase"
        static let deadline = "pomodoroStateDeadline"
        static let paused = "pomodoroStatePausedRemaining"
        static let planned = "pomodoroStatePlanned"
        static let rounds = "pomodoroStateRounds"
        static let startedAt = "pomodoroStatePhaseStartedAt"
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(phase.rawValue, forKey: Store.phase)
        d.set(deadline?.timeIntervalSince1970 ?? 0, forKey: Store.deadline)
        d.set(pausedRemaining ?? -1, forKey: Store.paused)
        d.set(plannedDuration, forKey: Store.planned)
        d.set(completedFocusRounds, forKey: Store.rounds)
        d.set(phaseStartedAt.timeIntervalSince1970, forKey: Store.startedAt)
    }

    private func restore() {
        let d = UserDefaults.standard
        phase = PomodoroPhase(rawValue: d.string(forKey: Store.phase) ?? "") ?? .focus
        plannedDuration = max(60, d.integer(forKey: Store.planned))
        completedFocusRounds = d.integer(forKey: Store.rounds)

        let started = d.double(forKey: Store.startedAt)
        phaseStartedAt = started > 0 ? Date(timeIntervalSince1970: started) : .now

        let paused = d.integer(forKey: Store.paused)
        pausedRemaining = paused >= 0 ? paused : nil

        let stored = d.double(forKey: Store.deadline)
        deadline = stored > 0 ? Date(timeIntervalSince1970: stored) : nil

        if deadline == nil && pausedRemaining == nil {
            plannedDuration = PomodoroSettings.duration(for: .focus)
        }
    }
}
