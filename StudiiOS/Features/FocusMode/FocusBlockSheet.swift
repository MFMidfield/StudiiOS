//
//  FocusBlockSheet.swift
//  บล็อกแอปอื่นระหว่างโฟกัส — เปิดจากปุ่มมุมขวาบนของหน้าโฟกัส
//
//  ปุ่ม "ปลดบล็อกฉุกเฉิน" **ถูกลบแล้ว** (15 ส.ค. 2569) —
//  `AppBlockManager.reconcile()` ที่ยิงตอนแอปกลับมา active ปลดให้เองอยู่แล้ว
//  เมื่อไม่มีรอบที่กำลังเดิน
//

import SwiftUI
import FamilyControls

struct FocusBlockSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var engine = PomodoroEngine.shared
    @State private var blocker = AppBlockManager.shared

    @AppStorage(PomodoroSettings.Key.blockAppsEnabled) private var blockAppsEnabled = false

    @State private var showAppPicker = false
    @State private var showAuthAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("บล็อกแอปอื่นตอนโฟกัส", isOn: $blockAppsEnabled)
                        .disabled(!engine.isIdle)
                } footer: {
                    Text("ใช้ Screen Time ของ iOS — เข้าแอปที่เลือกไม่ได้เลยจนหมดเวลา · เปลี่ยนได้เฉพาะตอนที่ยังไม่เริ่มโฟกัส")
                }

                if blockAppsEnabled {
                    Section {
                        Button {
                            showAppPicker = true
                        } label: {
                            HStack {
                                Label("เลือกแอปที่จะบล็อก", systemImage: "hand.raised.fill")
                                Spacer()
                                Text(blocker.selectionSummary)
                                    .font(Theme.Font.label)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                        .disabled(!engine.isIdle)
                    } footer: {
                        if !blocker.hasSelection {
                            Text("ยังไม่ได้เลือกแอป — เริ่มโฟกัสไปก็ยังไม่บล็อกอะไร")
                                .foregroundStyle(Theme.Colors.warning)
                        }
                    }
                }

                if let error = blocker.authorizationError, blockAppsEnabled {
                    Section {
                        Text(error)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
            .themedFormBackground()
            .navigationTitle("บล็อกแอป")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("เสร็จ") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $showAppPicker, selection: $blocker.selection)
            .alert("เปิดระบบบล็อกแอปไม่สำเร็จ", isPresented: $showAuthAlert) {
                Button("เข้าใจแล้ว", role: .cancel) {}
            } message: {
                Text(blocker.authorizationError ?? "ลองใหม่อีกครั้ง")
            }
            .onChange(of: blockAppsEnabled) { _, isOn in
                guard isOn else {
                    blocker.stopBlocking(reason: "ปิดสวิตช์")
                    return
                }
                Task {
                    let ok = await blocker.requestAuthorization()
                    if !ok {
                        blockAppsEnabled = false
                        showAuthAlert = true
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
