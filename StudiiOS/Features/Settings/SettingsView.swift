//
//  SettingsView.swift
//  ตั้งค่า — โปรไฟล์ · การเรียน · การแจ้งเตือน · การแสดงผล · เกี่ยวกับแอป
//  No login/account screens — V1 is offline-first with no cloud sync.
//
//  ยกเครื่องหน้าตา 16 ส.ค. 2569: ทิ้ง `List`/`Section` มาเป็น ScrollView +
//  CardContainer บนพื้น `Theme.Colors.background` ให้เข้าชุดกับหน้าอื่น
//
//  section "การเรียน" เดิม (6 แถว: ระดับชั้น · แก้ระดับชั้น · ขึ้นชั้นแล้ว ·
//  วิธีกรอกเทอมที่ผ่านมา · จัดการเทอม · โหมดโฟกัส) ยุบเหลือการ์ดใบเดียว:
//  เทอมปัจจุบัน + ปุ่มดินสอ (แก้ระดับชั้น) + ปุ่มลูกศรขึ้น (ขึ้นเทอมใหม่)
//  โหมดโฟกัสเข้าจากเมนูหน้าแรก · จัดการเทอมย้ายไปกล่องนักพัฒนา
//
//  Every developer tool (including the permanent-delete button, which used to
//  sit third from the top under a name that never said "delete") is behind
//  twenty taps on the version row. #if DEBUG alone was not enough: a demo runs
//  from Xcode, which IS a debug build, so the box would have been on screen
//  the whole time.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @State private var entitlements = EntitlementStore.shared
    @State private var profile = StudentProfileStore.shared
    @State private var notifications = NotificationManager.shared
    @State private var isConfirmingReset = false
    @State private var isPresentingIntro = false
    @State private var isPresentingEditProfile = false
    @State private var showTestNotificationHint = false
    @Environment(\.modelContext) private var context

    // "scheduleShowsPersonalTasks" is gone: ScheduleTodayTasksSection was its
    // only reader and that card was deleted, leaving a switch wired to nothing.

    @Query private var terms: [Term]

    /// Twenty taps on the version row reveal the developer box. Deliberately
    /// @State, not @AppStorage — it resets on every launch, so a demo can never
    /// start with the delete button already on screen.
    @State private var versionTapCount = 0
    @State private var isShowingDeveloperTools = false

    @AppStorage(AppTheme.storageKey) private var appTheme: AppTheme = .system

    /// Read back by AddTaskSheet when it builds a NEW task. Without that read
    /// this switch would be decoration — the model's own default is `false`.
    @AppStorage(SettingsView.reminderDefaultKey) private var remindersDefaultOn = true

    /// The key AddTaskSheet reads. Declared here because Settings owns the
    /// preference; AddTaskSheet only consumes it.
    static let reminderDefaultKey = "com.studentos.assignment.remindersDefaultOn"

    /// จำนวนครั้งที่ต้องแตะแถวเวอร์ชันเพื่อปลดล็อกกล่องนักพัฒนา
    private static let developerTapsRequired = 20

    // MARK: - Level 1 GPAX (D7: currentGradeLevel/currentTermNumber are the
    // student's REAL term — unrelated to TermStore.activeTermKey)

    @State private var isPresentingGradeLevelSheet = false
    @State private var isConfirmingAdvance = false
    @State private var isConfirmingGradeLevelEdit = false

    /// ทำให้การ์ด "การเรียน" อัปเดตทันทีที่ขึ้นเทอม/แก้ระดับชั้น — อ่าน `revision` ใน body
    @State private var gpaxStore = GPAXStore.shared

    // ping แบบ @AppStorage ของเดิม (พึ่งอย่างเดียวไม่ได้ ดู GPAXStore)
    @AppStorage(GPAXSettings.Key.currentGradeLevel) private var gpaxGradeLevelPing = 0
    @AppStorage(GPAXSettings.Key.currentTermNumber) private var gpaxTermNumberPing = 0

    // target / targetSource moved out entirely — GPAXTargetSheet on the grades
    // screen is now the only place a target is set.
    // โหมด "GPAX สะสม" ถูกถอดออกจาก UI 16 ส.ค. 2569 (GPAXSettings.entryMode
    // ค้างที่ .perTerm ตลอด ไม่มีใครเขียนอีกแล้ว)

    private var hasTerm: Bool { GPAXSettings.currentSortKey != nil }

    private var currentTermLabel: String {
        guard let level = GPAXSettings.currentGradeLevel, let term = GPAXSettings.currentTermNumber else {
            return "ยังไม่ได้ตั้ง"
        }
        return "ม.\(level) เทอม \(term)"
    }

    /// false once the student is already at ม.6 เทอม 2 — nothing further to advance to.
    private var canAdvanceTerm: Bool {
        guard let level = GPAXSettings.currentGradeLevel, let term = GPAXSettings.currentTermNumber else { return false }
        return !(level == 6 && term == 2)
    }

    private func advanceToNextTerm() {
        guard let level = GPAXSettings.currentGradeLevel, let term = GPAXSettings.currentTermNumber else { return }
        if term == 1 {
            GPAXSettings.setCurrentTerm(gradeLevel: level, termNumber: 2)
        } else if level < 6 {
            GPAXSettings.setCurrentTerm(gradeLevel: level + 1, termNumber: 1)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                let _ = gpaxStore.revision

                profileCard
                studyCard
                notificationCard
                displayCard
                aboutCard
                developerCard
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationTitle("ตั้งค่า")
        .task { await notifications.refreshStatus() }
        .alert("ส่งแจ้งเตือนทดสอบแล้ว", isPresented: $showTestNotificationHint) {
            Button("ตกลง", role: .cancel) { }
        } message: {
            Text("จะเด้งใน 5 วินาที ลองสลับออกจากแอปดูก็ได้")
        }
        .alert("เรียน \(currentTermLabel) จบแล้วใช่มั้ย", isPresented: $isConfirmingAdvance) {
            Button("ใช่", role: .destructive) { advanceToNextTerm() }
            Button("ไม่ใช่", role: .cancel) {}
        } message: {
            Text("ขึ้นเทอมใหม่แล้วเทอมนี้จะกรอกเกรดได้")
        }
        .alert("แก้ระดับชั้น?", isPresented: $isConfirmingGradeLevelEdit) {
            Button("แก้", role: .destructive) { isPresentingGradeLevelSheet = true }
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text("งานและเกรดที่ผูกกับเทอมเดิมจะไม่ตรงกับระดับชั้นใหม่")
        }
        .fullScreenCover(isPresented: $isPresentingIntro) {
            // NavigationStack ของตัวเอง: OnboardingScaffold ซ่อน nav bar
            // และเปิด edge swipe กลับ ซึ่งต้องมี stack ครอบถึงจะไม่พัง
            NavigationStack {
                OnboardingIntroView(actionTitle: "ปิด") { isPresentingIntro = false }
            }
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $isPresentingGradeLevelSheet) {
            GradeLevelSheet()
        }
        .confirmationDialog(
            "ลบข้อมูลทั้งหมดถาวร",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("ลบข้อมูลทั้งหมดและเริ่มใหม่", role: .destructive) {
                resetAllData()
            }
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text("ข้อมูลทั้งหมดในแอป (วิชา, งาน, โน้ต, ตารางเรียน, เกรด, โปรไฟล์ ฯลฯ) จะถูกลบถาวร แล้วพาคุณกลับไปหน้า Welcome ใหม่")
        }
    }

    // MARK: - โปรไฟล์

    /// The whole card is the button. The old design put a small "แก้ไข" link on
    /// the right, so the obvious target — the card — did nothing.
    private var profileCard: some View {
        Button {
            isPresentingEditProfile = true
        } label: {
            CardContainer {
                HStack(spacing: Theme.Spacing.md) {
                    profileAvatarView
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(profileSubtitle)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer(minLength: Theme.Spacing.sm)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - การเรียน

    /// การ์ดใบเดียวแทน 6 แถวเดิม: เทอมปัจจุบัน + ดินสอแก้ระดับชั้น + ลูกศรขึ้นเทอมใหม่
    private var studyCard: some View {
        CardContainer {
            Text("การเรียน")
                .font(Theme.Font.plex(13, .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.sm) {
                Text(currentTermLabel)
                    .font(Theme.Font.plex(24, .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer(minLength: Theme.Spacing.sm)

                if hasTerm {
                    Button {
                        isConfirmingGradeLevelEdit = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primaryDeep)
                            .frame(width: 40, height: 40)
                            .background(Theme.Colors.primarySoft)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("แก้ระดับชั้น")

                    if canAdvanceTerm {
                        Button {
                            isConfirmingAdvance = true
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.Colors.onPrimary)
                                .frame(width: 40, height: 40)
                                .background(Theme.Colors.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("ขึ้นเทอมใหม่")
                    }
                } else {
                    Button("ตั้งระดับชั้น") { isPresentingGradeLevelSheet = true }
                        .font(Theme.Font.plex(13, .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Colors.primary)
                }
            }
        }
    }

    // MARK: - การแจ้งเตือน

    private var notificationCard: some View {
        CardContainer {
            SectionHeader("การแจ้งเตือน")

            SettingsRow(title: "สถานะสิทธิ์", value: authorizationStatusLabel)

            if notifications.authorizationStatus == .notDetermined {
                Divider()
                Button("ขอสิทธิ์แจ้งเตือน") {
                    Task { await notifications.requestAuthorization() }
                }
                .font(Theme.Font.body)
                .tint(Theme.Colors.primaryDeep)
            }

            if notifications.authorizationStatus == .denied {
                Divider()
                Button("เปิดตั้งค่าแจ้งเตือนของเครื่อง") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(Theme.Font.body)
                .tint(Theme.Colors.primaryDeep)
            }

            Divider()

            Toggle("เตือนงานใหม่อัตโนมัติ", isOn: $remindersDefaultOn)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .tint(Theme.Colors.primary)

            Divider()

            NavigationLink {
                PendingNotificationsView()
            } label: {
                SettingsRow(title: "งานที่มีการแจ้งเตือน", showsChevron: true)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - การแสดงผล

    private var displayCard: some View {
        CardContainer {
            SectionHeader("การแสดงผล")

            // chip 3 ช่องเรียงนอน แทน Picker แบบเมนู — เห็นตัวเลือกครบโดยไม่ต้องกดเปิด
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(AppTheme.allCases) { theme in
                    themeChip(theme)
                }
            }
        }
    }

    private func themeChip(_ theme: AppTheme) -> some View {
        let isSelected = appTheme == theme

        return Button {
            appTheme = theme
        } label: {
            Text(theme.label)
                .font(Theme.Font.plex(13, isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Theme.Colors.onPrimary : Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isSelected ? Theme.Colors.primary : Theme.Colors.surfaceRaised, in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("ธีม \(theme.label)")
    }

    // MARK: - เกี่ยวกับแอป

    private var aboutCard: some View {
        CardContainer {
            SectionHeader("เกี่ยวกับแอป")

            Button("ดูหน้าแนะนำแอปอีกครั้ง") { isPresentingIntro = true }
                .font(Theme.Font.body)
                .tint(Theme.Colors.primaryDeep)

            Divider()

            SettingsRow(title: "เวอร์ชัน", value: "1.0.0")
                .contentShape(Rectangle())
                .onTapGesture(perform: registerVersionTap)

            Divider()

            HStack {
                Text("แผน")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if entitlements.hasPro || entitlements.hasPlus {
                    TierBadge(tier: entitlements.hasPlus ? .plus : .pro)
                } else {
                    Text("ฟรี")
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    /// Counts up to twenty, then stops counting — tapping further does nothing.
    private func registerVersionTap() {
        guard !isShowingDeveloperTools else { return }
        versionTapCount += 1
        if versionTapCount >= Self.developerTapsRequired {
            isShowingDeveloperTools = true
            AppLog.action("Settings", "ปลดล็อกเครื่องมือนักพัฒนา")
        }
    }

    // MARK: - Developer tools
    //
    // Two locks, not one: `#if DEBUG` keeps this out of a release build, and
    // the twenty-tap gate keeps it off screen during a demo — which runs from
    // Xcode and is therefore a debug build.
    //
    /// Kept out of `body` on purpose: `#if DEBUG` written inline inside a
    /// ViewBuilder confuses the type checker, so the conditional lives here
    /// and `body` just references the property.
    @ViewBuilder
    private var developerCard: some View {
        #if DEBUG
        if isShowingDeveloperTools {
            CardContainer {
                SectionHeader("สำหรับนักพัฒนา")

                Toggle("เปิด Pro", isOn: $entitlements.hasPro)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .tint(Theme.Colors.primary)

                Divider()

                Button("เปิดหน้า Setup อีกครั้ง") { startSetupTest() }
                    .font(Theme.Font.body)
                    .tint(Theme.Colors.primaryDeep)

                Button("ทดสอบแจ้งเตือน (5 วินาที)") {
                    Task {
                        await notifications.sendTestNotification()
                        showTestNotificationHint = true
                    }
                }
                .font(Theme.Font.body)
                .tint(Theme.Colors.primaryDeep)

                // ทางเข้าเดียวของหน้าจัดการเทอมตั้งแต่ 16 ส.ค. 2569 — เป็นหน้าที่ลบ
                // เทอมพร้อมงาน/คะแนนได้ ไม่ควรอยู่ในตั้งค่าปกติ
                NavigationLink {
                    TermManagementView()
                } label: {
                    SettingsRow(title: "จัดการเทอม", value: "\(terms.count) เทอม", showsChevron: true)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    OCRDebugView()
                } label: {
                    SettingsRow(title: "ทดสอบ OCR", showsChevron: true)
                }
                .buttonStyle(.plain)

                Divider()

                Button("ลบข้อมูลทั้งหมดถาวร", role: .destructive) {
                    isConfirmingReset = true
                }
                .font(Theme.Font.body)

                Text("กล่องนี้ไม่ขึ้นในเวอร์ชันจริง และซ่อนใหม่ทุกครั้งที่เปิดแอป")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        #endif
    }

    private var authorizationStatusLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "อนุญาตแล้ว"
        case .denied: return "ปิดอยู่"
        case .notDetermined: return "ยังไม่ได้ขอ"
        @unknown default: return "ไม่ทราบสถานะ"
        }
    }

    private var displayName: String {
        let fullName = [profile.firstName, profile.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return fullName.isEmpty ? "ยังไม่ได้ตั้งชื่อ" : fullName
    }

    /// ชื่อเล่นอย่างเดียว — ระดับชั้น/เทอมถูกเอาออก 16 ส.ค. 2569 เพราะการ์ด "การเรียน"
    /// ที่อยู่ถัดลงมาบอกอยู่แล้ว
    private var profileSubtitle: String {
        profile.nickname.isEmpty ? profile.firstName : profile.nickname
    }

    /// Initials on a soft accent circle beat a grey stock silhouette — the card
    /// looks set up even before a photo is added.
    @ViewBuilder
    private var profileAvatarView: some View {
        if let img = profile.cachedProfileImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Theme.Colors.primarySoft)
                .overlay {
                    Text(initials)
                        .font(Theme.Font.plex(17, .semibold))
                        .foregroundStyle(Theme.Colors.primaryDeep)
                }
        }
    }

    /// First letter of the nickname, else of the first name, else a person glyph.
    private var initials: String {
        let source = profile.nickname.isEmpty ? profile.firstName : profile.nickname
        return source.isEmpty ? "?" : String(source.prefix(1))
    }

    /// Debug-only: wipes every SwiftData record plus the local profile, then
    /// resets every onboarding/setup flag so the app restarts from Welcome.
    private func resetAllData() {
        deleteAll(Assignment.self)
        deleteAll(Note.self)
        deleteAll(Flashcard.self)
        deleteAll(GradeComponent.self)
        deleteAll(ExamEvent.self)
        deleteAll(ScheduleEntry.self)
        deleteAll(FocusSession.self)
        deleteAll(FocusTag.self)
        deleteAll(PortfolioItem.self)
        deleteAll(PortfolioImage.self)
        PortfolioImageStore.deleteAll()
        deleteAll(CareerInterestResult.self)
        deleteAll(SOPDocument.self)
        deleteAll(SOPTarget.self)
        deleteAll(SemesterRecord.self)
        deleteAll(CalendarEvent.self)
        deleteAll(CalendarTag.self)
        deleteAll(CalendarAttachmentItem.self)
        deleteAll(Subject.self)
        deleteAll(DayScheduleOverride.self)
        deleteAll(TermSubject.self)
        deleteAll(TermGradeSubject.self)
        deleteAll(Term.self)

        NotificationManager.shared.cancelAll()
        StudentProfileStore.shared.reset()

        // GPAX lives in UserDefaults, not SwiftData — without this the wipe
        // left "ระดับชั้น ม.5 เทอม 1" and the target sitting there afterwards.
        // Device preferences (ธีม · ค่าเริ่มต้นการเตือน · PomodoroSettings) are
        // deliberately kept: they are not the student's data.
        GPAXSettings.resetAll()

        // การบล็อกแอปเป็นค่าระดับ**ระบบ** ไม่ได้อยู่ใน SwiftData — ถ้าไม่เคลียร์
        // ตรงนี้ ล้างข้อมูลแล้วแอปอื่นจะยังถูกบล็อกค้างอยู่
        PomodoroEngine.shared.stop(recordPartial: false)
        AppBlockManager.shared.stopBlocking(reason: "ล้างข้อมูลทั้งหมด")

        StudiiOSApp.seedBuiltInSubjects(in: context)

        // ล้างข้อมูลแล้วต้องกลับไปตั้งค่าใหม่ ไม่งั้นแอปเปิดมาที่ Dashboard เปล่าๆ
        // โดยไม่มีทางบอกได้อีกว่าตอนนี้อยู่ ม.อะไร เทอมไหน
        OnboardingGate.reset()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        items.forEach { context.delete($0) }
    }

    /// Debug-only: shows the setup flow again as the app's root — the same place a
    /// new student meets it, not inside a cover presented from here. The "setup is
    /// done" flag is untouched; the flow's own ✕ (DEBUG only) puts things back.
    private func startSetupTest() {
        #if DEBUG
        OnboardingGate.startReplay()
        #endif
    }
}

/// แถว "ชื่อ · ค่า" ในการ์ด — แทน `LabeledContent` ที่ผูกกับสไตล์ของ List
private struct SettingsRow: View {
    let title: String
    var value: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: Theme.Spacing.sm)
            if let value {
                Text(value)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
