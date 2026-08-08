//
//  AppBlockManager.swift
//  บล็อกแอปอื่นจริงระดับระบบด้วย Screen Time API
//
//  ── สิ่งที่ต้องรู้ก่อนแตะไฟล์นี้ ───────────────────────────────────────────
//  1. ต้องเปิด Capability **Family Controls** ที่ target ใน Xcode
//     (Signing & Capabilities → + Capability → Family Controls)
//     entitlement ตัว development ใช้ได้ทันทีไม่ต้องรอ Apple อนุมัติ
//     ที่ต้องขออนุมัติคือตอนจะขึ้น TestFlight/App Store เท่านั้น
//  2. **ใช้บน Simulator ไม่ได้** — `requestAuthorization` จะคืน error เสมอ
//     ต้องรันบน iPhone จริง โค้ดทั้งไฟล์จึงออกแบบให้ "ล้มเหลวแบบเงียบ"
//     คือถ้าขออนุญาตไม่ผ่าน แอปยังใช้งานต่อได้ปกติ แค่ไม่บล็อกแอปอื่น
//  3. Shield ที่แอปเราสั่ง **ไม่มีปุ่ม "Ignore Limit"** — ปุ่มนั้นเป็นของแอป
//     Settings ของ Apple เอง ผู้ใช้กดปิด shield ได้แค่เด้งกลับหน้า Home
//     ไม่สามารถเข้าแอปที่ถูกบล็อกได้
//  4. การบล็อกเป็นค่าระดับ**ระบบ** ไม่ใช่ของแอปเรา → ถ้าไม่เคลียร์ แอปจะถูก
//     บล็อกค้างแม้ลบ Student OS ไปแล้ว จึงมี `reconcile()` เรียกทุกครั้งที่
//     แอปกลับมา active และปุ่มปลดล็อกฉุกเฉินใน Settings
//

import Foundation
import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

extension ManagedSettingsStore.Name {
    static let studentOSFocus = Self("studentOSFocus")
}

extension DeviceActivityName {
    static let studentOSFocus = Self("studentOSFocus")
}

@Observable
@MainActor
final class AppBlockManager {

    static let shared = AppBlockManager()

    /// ขออนุญาต Screen Time ผ่านแล้วหรือยัง
    private(set) var isAuthorized = false
    /// ข้อความ error ล่าสุดจากการขออนุญาต — โชว์ให้ผู้ใช้เห็นตรงๆ
    private(set) var authorizationError: String?
    /// กำลังบล็อกอยู่ไหม
    private(set) var isBlocking = false

    /// แอป/หมวด/เว็บที่ผู้ใช้เลือกจะบล็อก (เก็บเป็น token ทึบ อ่านชื่อไม่ได้)
    var selection = FamilyActivitySelection() {
        didSet { saveSelection() }
    }

    private let store = ManagedSettingsStore(named: .studentOSFocus)
    private let activityCenter = DeviceActivityCenter()

    private enum Store {
        static let selection = "focusBlockSelection"
        static let blockingUntil = "focusBlockingUntil"
    }

    private init() {
        loadSelection()
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// มีอะไรให้บล็อกไหม
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    var selectionSummary: String {
        guard hasSelection else { return "ยังไม่ได้เลือกแอป" }
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty {
            parts.append("\(selection.applicationTokens.count) แอป")
        }
        if !selection.categoryTokens.isEmpty {
            parts.append("\(selection.categoryTokens.count) หมวด")
        }
        if !selection.webDomainTokens.isEmpty {
            parts.append("\(selection.webDomainTokens.count) เว็บไซต์")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - ขออนุญาต

    /// ขอสิทธิ์ Screen Time — ต้องเรียกก่อนบล็อกครั้งแรก
    /// ล้มเหลวได้ปกติ (Simulator / ผู้ใช้ปฏิเสธ / บัญชีเด็กที่ต้องรอผู้ปกครอง)
    /// ผู้เรียกต้องเช็ค `isAuthorized` เสมอ ห้ามถือว่าสำเร็จ
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            authorizationError = isAuthorized ? nil : "ยังไม่ได้รับอนุญาต"
            AppLog.action("AppBlock", "ขออนุญาต Screen Time: \(isAuthorized ? "ผ่าน" : "ไม่ผ่าน")")
            return isAuthorized
        } catch {
            isAuthorized = false
            authorizationError = Self.friendlyMessage(for: error)
            AppLog.error("AppBlock", "ขออนุญาตไม่ผ่าน: \(error)")
            return false
        }
    }

    private static func friendlyMessage(for error: Error) -> String {
        #if targetEnvironment(simulator)
        return "ระบบบล็อกแอปใช้บน Simulator ไม่ได้ ต้องรันบน iPhone จริง"
        #else
        if let famError = error as? FamilyControlsError {
            switch famError {
            case .invalidAccountType:
                return "บัญชี Apple นี้ใช้ไม่ได้ — ต้องเป็นบัญชีผู้ใช้ทั่วไป หรือให้ผู้ปกครองอนุมัติ"
            case .authorizationCanceled:
                return "ยกเลิกการขออนุญาต"
            case .authorizationConflict:
                return "มีแอปอื่นถือสิทธิ์ Screen Time อยู่"
            case .networkError:
                return "ต่ออินเทอร์เน็ตไม่ได้ ลองใหม่อีกครั้ง"
            case .restricted:
                return "เครื่องนี้ถูกจำกัดสิทธิ์ Screen Time ไว้"
            default:
                return "ขออนุญาตไม่สำเร็จ: \(famError.localizedDescription)"
            }
        }
        return "ขออนุญาตไม่สำเร็จ: \(error.localizedDescription)"
        #endif
    }

    // MARK: - บล็อก / ปลดบล็อก

    /// เริ่มบล็อกจนถึงเวลาที่กำหนด
    /// ปลอดภัยที่จะเรียกซ้ำ — ถ้าเงื่อนไขไม่ครบจะเงียบไปเฉยๆ ไม่ crash
    func startBlocking(until deadline: Date) {
        guard isAuthorized, hasSelection, deadline > .now else { return }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens

        isBlocking = true
        UserDefaults.standard.set(deadline.timeIntervalSince1970, forKey: Store.blockingUntil)

        startSafetyMonitor(until: deadline)
        AppLog.action("AppBlock", "เริ่มบล็อกถึง \(deadline)")
    }

    /// ปลดบล็อกทั้งหมด — เรียกได้ทุกเมื่อ ไม่ต้องเช็คอะไรก่อน
    func stopBlocking(reason: String = "") {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.clearAllSettings()

        activityCenter.stopMonitoring([.studentOSFocus])

        isBlocking = false
        UserDefaults.standard.removeObject(forKey: Store.blockingUntil)
        if !reason.isEmpty {
            AppLog.action("AppBlock", "ปลดบล็อก (\(reason))")
        }
    }

    /// กันแอปค้างบล็อก — เรียกทุกครั้งที่แอปกลับมา active
    /// ถ้าเลยเวลาที่ตั้งไว้แล้ว (หรือไม่เคยตั้ง) ให้ปลดบล็อกทิ้ง
    func reconcile() {
        let until = UserDefaults.standard.double(forKey: Store.blockingUntil)
        guard until > 0 else {
            if isBlocking { stopBlocking(reason: "ไม่มีเซสชันค้าง") }
            return
        }
        if Date(timeIntervalSince1970: until) <= .now {
            stopBlocking(reason: "เลยเวลาที่ตั้งไว้")
        } else {
            isBlocking = true
        }
    }

    /// ตาข่ายกันพลาดชั้นที่สอง: ให้ระบบเลิก monitor เองเมื่อครบเวลา
    /// (ตัวปลดบล็อกหลักคือแอปเรา — อันนี้ไว้เผื่อผู้ใช้บังคับปิดแอปทิ้ง)
    /// DeviceActivitySchedule ต้องมีช่วงยาวอย่างน้อย ~15 นาที ถ้าสั้นกว่านั้นจะ throw
    /// จึงจับ error ทิ้งเงียบๆ ได้ ไม่กระทบการบล็อกที่ตั้งไปแล้ว
    private func startSafetyMonitor(until deadline: Date) {
        let cal = Calendar.current
        let start = cal.dateComponents([.hour, .minute, .second], from: .now)
        let end = cal.dateComponents([.hour, .minute, .second], from: deadline)
        let schedule = DeviceActivitySchedule(
            intervalStart: start,
            intervalEnd: end,
            repeats: false
        )
        do {
            activityCenter.stopMonitoring([.studentOSFocus])
            try activityCenter.startMonitoring(.studentOSFocus, during: schedule)
        } catch {
            AppLog.error("AppBlock", "ตั้ง safety monitor ไม่สำเร็จ (ไม่กระทบการบล็อก): \(error)")
        }
    }

    // MARK: - เก็บรายการที่เลือก

    private func saveSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: Store.selection)
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: Store.selection),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }
}
