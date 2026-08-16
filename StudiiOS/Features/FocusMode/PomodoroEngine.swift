//
//  PomodoroEngine.swift
//  หัวใจของโหมดโฟกัส — จุดเดียวที่รู้ว่า "ตอนนี้เหลือ/ผ่านไปกี่วินาที"
//
//  หลักการสำคัญ: **นับจาก Date ไม่ใช่นับ tick**
//  ของเดิมใช้ `secondsRemaining -= 1` ทุกวินาที ซึ่งพังทันทีที่แอปเข้า background
//  (Timer หยุด → เวลาค้าง) เวอร์ชันนี้เก็บ `deadline`/`phaseStartedAt` เป็น Date
//  แล้วคำนวณสดทุกครั้งที่วาด → ปิดจอ/สลับแอป/บังคับปิดแอปแล้วกลับมา เวลาก็ยังถูก
//
//  สถานะทั้งหมดถูก mirror ลง UserDefaults เพื่อให้กู้กลับได้หลัง force-quit —
//  จำเป็นมาก เพราะโหมดบล็อกแอปเป็นการตั้งค่าระดับ**ระบบ** ถ้ากู้สถานะไม่ได้
//  แอปที่ถูกบล็อกจะค้างบล็อกตลอดไป
//
//  ยกเครื่อง 15 ส.ค. 2569 — สิ่งที่หายไปจากเวอร์ชันก่อน:
//  · หยุดชั่วคราว (`pause`/`resume`) — หน้าใหม่ไม่มีปุ่ม หยุดได้ทางเดียวคือกดค้าง
//  · พักยาว · การนับรอบ · `autoContinue` — พักคงที่ 5 นาที และ**ถามทุกครั้ง**
//  สิ่งที่เพิ่มมา:
//  · `Mode.countUp` (∞) นับขึ้นจาก 0 หยุดเองที่ 180 นาที
//  · `isAskingForBreak` — จบรอบโฟกัสแล้วรอผู้ใช้ตอบว่าจะพักไหม
//  · `activeTag` — สำเนาแท็กที่ติดไปกับ FocusSession
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class PomodoroEngine {

    static let shared = PomodoroEngine()

    /// นับถอยหลังจากเวลาที่เลือก หรือนับขึ้นแบบ ∞
    enum Mode: String {
        case countdown
        case countUp
    }

    // MARK: - สถานะที่ View อ่าน

    private(set) var phase: PomodoroPhase = .focus
    private(set) var mode: Mode = .countdown
    /// เวลาที่ช่วงปัจจุบันจะหมด — nil = ไม่ได้กำลังเดิน
    /// (โหมด ∞ ก็มี deadline คือเพดาน 180 นาที)
    private(set) var deadline: Date?
    /// ความยาวเต็มของช่วงปัจจุบัน (วินาที)
    private(set) var plannedDuration: Int = PomodoroSettings.defaultFocusMinutes * 60
    /// เวลาที่ช่วงปัจจุบันเริ่ม
    private(set) var phaseStartedAt: Date = .now
    /// แท็กของรอบนี้ — nil = ไม่ได้เลือก
    private(set) var activeTag: FocusTagSnapshot?
    /// รอบโฟกัสเพิ่งจบ กำลังรอผู้ใช้กด "พัก" หรือ "ไม่พัก"
    private(set) var isAskingForBreak = false

    /// ตัวขับการวาดใหม่ — เปลี่ยนทุก 0.5 วิ ให้ View คำนวณเวลาใหม่
    private(set) var tickToken: Int = 0

    // MARK: - สถานะภายใน

    private var ticker: Timer?
    private var context: ModelContext?

    /// ถ้ากลับมาช้ากว่านี้หลังหมดเวลา ถือว่าเลิกรอบ ไม่ต้องถามเรื่องพักแล้ว
    /// (กันกรณีปิดแอปทิ้ง 3 ชั่วโมงแล้วเปิดมาเจอกล่องถามพักค้างอยู่)
    private let breakPromptGrace: TimeInterval = 5 * 60

    private init() {
        restore()
    }

    // MARK: - ค่าที่คำนวณให้ View

    var isRunning: Bool { deadline != nil }
    var isIdle: Bool { deadline == nil }
    var isBreak: Bool { phase.isBreak }

    /// วินาทีที่ผ่านไปแล้วในช่วงนี้ — คำนวณสดจากนาฬิกาจริง
    var elapsedSeconds: Int {
        max(0, Int(Date.now.timeIntervalSince(phaseStartedAt)))
    }

    /// วินาทีที่เหลือ — คำนวณสดจากนาฬิกาจริง
    var secondsRemaining: Int {
        guard let deadline else { return 0 }
        return max(0, Int(deadline.timeIntervalSinceNow.rounded(.up)))
    }

    /// ตัวเลขที่เอาไปโชว์: โหมด ∞ นับขึ้น · โหมดปกตินับถอยหลัง
    var displaySeconds: Int {
        guard isRunning else { return plannedDuration }
        if mode == .countUp && phase == .focus {
            return min(elapsedSeconds, plannedDuration)
        }
        return secondsRemaining
    }

    var progress: Double {
        guard plannedDuration > 0 else { return 0 }
        if mode == .countUp && phase == .focus {
            return min(1, Double(elapsedSeconds) / Double(plannedDuration))
        }
        return 1 - Double(secondsRemaining) / Double(plannedDuration)
    }

    /// รูปแบบ `mm:ss` — เกิน 1 ชั่วโมงเป็น `h:mm:ss`
    var timeString: String {
        let s = displaySeconds
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: - ผูก SwiftData

    /// เรียกจาก `.task` ของหน้าโฟกัส — ต้องมีก่อนถึงจะบันทึกสถิติได้
    func attach(context: ModelContext) {
        self.context = context
    }

    // MARK: - คำสั่งหลัก

    /// เริ่มรอบโฟกัส
    /// - Parameters:
    ///   - minutes: `0` หรือน้อยกว่า = โหมด ∞ (นับขึ้น หยุดเองที่ 180 นาที)
    ///   - tag: แท็กที่เลือก — nil ได้ (ไม่บังคับเลือก)
    func startFocus(minutes: Int, tag: FocusTagSnapshot?) {
        activeTag = tag
        isAskingForBreak = false

        if minutes <= 0 {
            mode = .countUp
            begin(phase: .focus, seconds: PomodoroSettings.maxMinutes * 60, at: .now)
        } else {
            mode = .countdown
            begin(phase: .focus, seconds: min(minutes, PomodoroSettings.maxMinutes) * 60, at: .now)
        }
    }

    /// ผู้ใช้ตอบว่า "พัก" — 5 นาทีคงที่
    func startBreak() {
        isAskingForBreak = false
        mode = .countdown
        // ช่วงพักไม่บล็อกแอป ผู้ใช้ควรได้พักจริง
        AppBlockManager.shared.stopBlocking(reason: "ถึงเวลาพัก")
        begin(phase: .shortBreak, seconds: PomodoroSettings.breakMinutes * 60, at: .now)
    }

    /// ผู้ใช้ตอบว่า "ไม่พัก" — จบรอบ กลับหน้าเริ่มต้น
    func declineBreak() {
        isAskingForBreak = false
        activeTag = nil
        phase = .focus
        persist()
        AppLog.action("Focus", "ไม่พัก จบรอบ")
    }

    /// จบทุกอย่างเดี๋ยวนี้ — ใช้ทั้งตอนกดค้าง 5 วิ และตอนล้างข้อมูลในหน้าตั้งค่า
    /// - Parameter recordPartial: บันทึกเวลาที่ทำไปแล้วลงสถิติไหม
    func stop(recordPartial: Bool = true) {
        if recordPartial, isRunning {
            recordInterrupted(at: .now)
        }
        deadline = nil
        phase = .focus
        mode = .countdown
        isAskingForBreak = false
        activeTag = nil
        plannedDuration = PomodoroSettings.duration(for: .focus)
        stopTicker()
        NotificationManager.shared.cancelFocusNotification()
        AppBlockManager.shared.stopBlocking(reason: "จบเซสชัน")
        persist()
        AppLog.action("Focus", "หยุดเซสชัน")
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

        let endedPhase = phase
        let overdue = Date.now.timeIntervalSince(deadline)

        insertSession(
            phase: endedPhase,
            seconds: plannedDuration,
            completed: true,
            endedAt: deadline
        )

        self.deadline = nil
        stopTicker()
        NotificationManager.shared.cancelFocusNotification()
        AppBlockManager.shared.stopBlocking(reason: "หมดเวลาแล้ว")

        // ถามเรื่องพักเฉพาะรอบโฟกัสแบบนับถอยหลัง และเฉพาะตอนที่ผู้ใช้ยังอยู่กับแอป
        // โหมด ∞ ครบ 180 นาที = จบเลย ไม่ถาม (ตามสเปค)
        isAskingForBreak = endedPhase == .focus
            && mode == .countdown
            && overdue <= breakPromptGrace

        if !isAskingForBreak {
            activeTag = nil
            phase = .focus
        }
        persist()
        AppLog.action("Focus", "จบช่วง \(endedPhase.label) · ถามพัก=\(isAskingForBreak)")
    }

    // MARK: - ภายใน

    private func begin(phase newPhase: PomodoroPhase, seconds: Int, at start: Date) {
        phase = newPhase
        plannedDuration = max(60, seconds)
        phaseStartedAt = start
        deadline = start.addingTimeInterval(TimeInterval(plannedDuration))

        startTicker()
        scheduleEndNotification()
        applyBlockingIfNeeded()
        persist()
        AppLog.action("Focus", "เริ่ม \(newPhase.label) \(plannedDuration / 60) นาที (\(mode.rawValue))")
    }

    /// บันทึกรอบที่ถูกกดหยุดกลางคัน
    ///
    /// โหมด ∞ ที่ทำได้ ≥10 นาที นับเป็น **สำเร็จ** (ผู้ใช้ตั้งใจให้เป็นแบบนั้น —
    /// นาฬิกาจับเวลาไม่มีเส้นชัยของตัวเอง) นอกนั้นเป็นรอบไม่สำเร็จ
    private func recordInterrupted(at endedAt: Date) {
        let elapsed = min(elapsedSeconds, plannedDuration)
        guard elapsed >= PomodoroSettings.minimumRecordedSeconds else { return }
        let succeeded = phase == .focus
            && mode == .countUp
            && elapsed >= PomodoroSettings.countUpSuccessSeconds
        insertSession(phase: phase, seconds: elapsed, completed: succeeded, endedAt: endedAt)
    }

    private func insertSession(phase: PomodoroPhase, seconds: Int, completed: Bool, endedAt: Date) {
        guard let context, seconds > 0 else { return }
        let session = FocusSession(
            startedAt: endedAt.addingTimeInterval(-TimeInterval(seconds)),
            durationSeconds: seconds,
            completed: completed,
            phase: phase,
            endedAt: endedAt,
            wasLocked: PomodoroSettings.blockAppsEnabled,
            tag: phase == .focus ? activeTag : nil
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
        let body: String
        if endingPhase != .focus {
            body = "พักครบแล้ว กลับมาต่อได้เลย"
        } else if mode == .countUp {
            // โหมด ∞ ไม่มีคำถามเรื่องพัก — ชนเพดาน 180 นาทีแล้วจบเลย
            body = "ครบ \(PomodoroSettings.maxMinutes) นาทีแล้ว เซสชันจบลงเอง"
        } else {
            body = "เปิดแอปเพื่อเลือกว่าจะพัก \(PomodoroSettings.breakMinutes) นาทีไหม"
        }
        Task {
            await NotificationManager.shared.scheduleFocusEnd(
                at: deadline,
                phase: endingPhase,
                body: body
            )
        }
    }

    // MARK: - Ticker (ใช้แค่กระตุ้นให้ View วาดใหม่ ไม่ได้ใช้นับเวลา)

    private func startTicker() {
        guard ticker == nil, deadline != nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
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
        static let planned = "pomodoroStatePlanned"
        static let startedAt = "pomodoroStatePhaseStartedAt"
        static let mode = "pomodoroStateMode"
        static let tag = "pomodoroStateTag"
        static let askingBreak = "pomodoroStateAskingBreak"
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(phase.rawValue, forKey: Store.phase)
        d.set(deadline?.timeIntervalSince1970 ?? 0, forKey: Store.deadline)
        d.set(plannedDuration, forKey: Store.planned)
        d.set(phaseStartedAt.timeIntervalSince1970, forKey: Store.startedAt)
        d.set(mode.rawValue, forKey: Store.mode)
        d.set(isAskingForBreak, forKey: Store.askingBreak)

        if let activeTag, let data = try? JSONEncoder().encode(activeTag) {
            d.set(data, forKey: Store.tag)
        } else {
            d.removeObject(forKey: Store.tag)
        }
    }

    private func restore() {
        let d = UserDefaults.standard
        phase = PomodoroPhase(rawValue: d.string(forKey: Store.phase) ?? "") ?? .focus
        plannedDuration = max(60, d.integer(forKey: Store.planned))
        mode = Mode(rawValue: d.string(forKey: Store.mode) ?? "") ?? .countdown
        isAskingForBreak = d.bool(forKey: Store.askingBreak)

        let started = d.double(forKey: Store.startedAt)
        phaseStartedAt = started > 0 ? Date(timeIntervalSince1970: started) : .now

        let stored = d.double(forKey: Store.deadline)
        deadline = stored > 0 ? Date(timeIntervalSince1970: stored) : nil

        if let data = d.data(forKey: Store.tag) {
            activeTag = try? JSONDecoder().decode(FocusTagSnapshot.self, from: data)
        }

        if deadline == nil {
            plannedDuration = PomodoroSettings.duration(for: .focus)
        }
    }
}
