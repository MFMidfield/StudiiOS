//
//  PermissionsSetupView.swift
//  หน้า 6 ของ setup — ขอสิทธิ์แล้วเข้าแอป
//
//  ทั้งสองอย่างเป็นตัวเลือก: ปุ่ม "เข้าสู่แอป" กดได้ตลอด ไม่ว่าจะให้สิทธิ์หรือไม่
//  แต่ละแถวมีปุ่มของตัวเอง เพื่อให้ผู้ใช้เห็นว่ากำลังจะอนุญาตอะไรก่อนกล่องของ
//  ระบบเด้ง — ยิงขอรวดเดียวสองอันคือวิธีที่ทำให้คนกดปฏิเสธทั้งคู่
//
//  iOS ถามได้ครั้งเดียวต่อสิทธิ์หนึ่งอย่างตลอดอายุการติดตั้ง ถ้าเคยปฏิเสธไปแล้ว
//  ปุ่มจะพาไปหน้า ตั้งค่า ของระบบแทน (กล่องเดิมไม่เด้งอีก)
//

import SwiftUI
import AVFoundation
import UserNotifications
import UIKit

struct PermissionsSetupView: View {
    let onBack: () -> Void
    let onFinish: () -> Void

    @State private var notifications = NotificationManager.shared
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var isRequestingNotifications = false

    var body: some View {
        OnboardingScaffold(
            step: .permissions,
            onBack: onBack,
            primaryTitle: "เข้าสู่แอป",
            onPrimary: onFinish
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                notificationRow
                cameraRow
                footnote
            }
        }
        .task { await notifications.refreshStatus() }
    }

    // MARK: - Rows

    private var notificationRow: some View {
        PermissionRow(
            icon: "bell.badge.fill",
            title: "การแจ้งเตือน",
            detail: "เตือนก่อนถึงกำหนดส่งงาน และตอนหมดเวลาโหมดโฟกัส",
            state: notificationState,
            isBusy: isRequestingNotifications,
            action: requestNotifications
        )
    }

    private var cameraRow: some View {
        PermissionRow(
            icon: "camera.fill",
            title: "กล้อง",
            detail: "ถ่ายตารางเรียนให้แอปอ่านให้ และสแกนเกียรติบัตรเก็บเข้าแฟ้มผลงาน",
            state: cameraState,
            isBusy: false,
            action: requestCamera
        )
    }

    private var footnote: some View {
        Text("ไม่ให้ตอนนี้ก็ใช้แอปได้ครบทุกอย่าง ยกเว้นสองข้อข้างบน เปิดทีหลังได้ที่ ตั้งค่า ของเครื่อง")
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - State

    private var notificationState: PermissionRow.State {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .blocked
        default: return .askable
        }
    }

    private var cameraState: PermissionRow.State {
        switch cameraStatus {
        case .authorized: return .granted
        case .denied, .restricted: return .blocked
        default: return .askable
        }
    }

    // MARK: - Actions

    private func requestNotifications() {
        guard notificationState != .granted else { return }
        guard notificationState != .blocked else { return openSystemSettings() }

        isRequestingNotifications = true
        Task {
            _ = await notifications.requestAuthorization()
            await notifications.refreshStatus()
            isRequestingNotifications = false
        }
    }

    private func requestCamera() {
        guard cameraState != .granted else { return }
        guard cameraState != .blocked else { return openSystemSettings() }

        AVCaptureDevice.requestAccess(for: .video) { _ in
            Task { @MainActor in
                cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Row

private struct PermissionRow: View {
    enum State {
        /// ยังไม่เคยถาม — กดแล้วกล่องของระบบจะเด้ง
        case askable
        case granted
        /// เคยปฏิเสธไปแล้ว กล่องเดิมไม่เด้งอีก ต้องไปเปิดที่ ตั้งค่า ของเครื่อง
        case blocked
    }

    let icon: String
    let title: String
    let detail: String
    let state: State
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        CardContainer {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                IconTile(systemName: icon, size: 44)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(detail)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    actionControl
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var actionControl: some View {
        switch state {
        case .granted:
            Label("อนุญาตแล้ว", systemImage: "checkmark.circle.fill")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.success)
        case .askable, .blocked:
            Button(action: action) {
                HStack(spacing: Theme.Spacing.xs) {
                    if isBusy { ProgressView().controlSize(.small) }
                    Text(state == .blocked ? "เปิดในตั้งค่าเครื่อง" : "อนุญาต")
                        .font(Theme.Font.plex(14, .medium))
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.primarySoft)
                .foregroundStyle(Theme.Colors.primaryDeep)
                .clipShape(Capsule())
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isBusy)
        }
    }
}
