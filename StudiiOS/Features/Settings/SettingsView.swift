//
//  SettingsView.swift
//  ตั้งค่า — โปรไฟล์ · การเรียน · การแจ้งเตือน · เกี่ยวกับแอป
//  No login/account screens — V1 is offline-first with no cloud sync.
//
//  Every developer tool (including the permanent-delete button, which used to
//  sit third from the top under a name that never said "delete") is behind
//  seven taps on the version row. #if DEBUG alone was not enough: a demo runs
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
    @State private var isPresentingWelcome = false
    @State private var isConfirmingReset = false
    @State private var isPresentingSetupTest = false
    @State private var isPresentingEditProfile = false
    @State private var showTestNotificationHint = false
    @State private var savedSetupFlags: (profile: Bool, schedule: Bool, grade: Bool, summary: Bool)?
    @Environment(\.modelContext) private var context

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    @AppStorage("hasCompletedScheduleSetup") private var hasCompletedScheduleSetup = false
    @AppStorage("hasCompletedGradeSetup") private var hasCompletedGradeSetup = false
    @AppStorage("hasCompletedSetupSummary") private var hasCompletedSetupSummary = false

    // "scheduleShowsPersonalTasks" is gone: ScheduleTodayTasksSection was its
    // only reader and that card was deleted, leaving a switch wired to nothing.

    @Query private var terms: [Term]

    /// Seven taps on the version row reveal the developer box. Deliberately
    /// @State, not @AppStorage — it resets on every launch, so a demo can never
    /// start with the delete button already on screen.
    @State private var versionTapCount = 0
    @State private var isShowingDeveloperTools = false

    // MARK: - Level 1 GPAX (D7: currentGradeLevel/currentTermNumber are the
    // student's REAL term — unrelated to TermStore.activeTermKey)

    @State private var isPresentingGradeLevelSheet = false
    @State private var isPresentingCumulativeSheet = false

    // Ping pattern (see GradeCenterView) — makes SwiftUI redraw currentTermLabel
    // after GradeLevelSheet or advanceToNextTerm() write these keys.
    @AppStorage(GPAXSettings.Key.currentGradeLevel) private var gpaxGradeLevelPing = 0
    @AppStorage(GPAXSettings.Key.currentTermNumber) private var gpaxTermNumberPing = 0

    // target / targetSource moved out entirely — GPAXTargetSheet on the grades
    // screen is now the only place a target is set.
    @AppStorage(GPAXSettings.Key.entryMode) private var gpaxEntryMode: GPAXSettings.EntryMode = .perTerm
    @AppStorage(GPAXSettings.Key.priorGPAX) private var gpaxPriorGPAX: Double = 0
    @AppStorage(GPAXSettings.Key.priorTermCount) private var gpaxPriorTermCount: Int = 0

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
        List {
            profileSection
            studySection
            notificationSection
            aboutSection
            developerSection
        }
        .navigationTitle("ตั้งค่า")
        .task { await notifications.refreshStatus() }
        .alert("ส่งแจ้งเตือนทดสอบแล้ว", isPresented: $showTestNotificationHint) {
            Button("ตกลง", role: .cancel) { }
        } message: {
            Text("จะเด้งใน 5 วินาที ลองสลับออกจากแอปดูก็ได้")
        }
        .fullScreenCover(isPresented: $isPresentingWelcome) {
            WelcomeView()
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $isPresentingGradeLevelSheet) {
            GradeLevelSheet()
        }
        .sheet(isPresented: $isPresentingCumulativeSheet) {
            CumulativeGPAXSheet()
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

    // MARK: - Sections

    /// The whole card is the button. The old design put a small "แก้ไข" link on
    /// the right, so the obvious target — the card — did nothing.
    private var profileSection: some View {
        Section {
            Button {
                isPresentingEditProfile = true
            } label: {
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
                .padding(.vertical, Theme.Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var studySection: some View {
        Section("การเรียน") {
            LabeledContent("ระดับชั้นปัจจุบัน", value: currentTermLabel)

            Button(GPAXSettings.currentSortKey == nil ? "ตั้งระดับชั้น" : "แก้ระดับชั้น") {
                isPresentingGradeLevelSheet = true
            }

            // Referenced by name in the grades list ("กด \"ขึ้นชั้นแล้ว\" ในตั้งค่า")
            // — do not rename without changing that copy too.
            if canAdvanceTerm {
                Button("ขึ้นชั้นแล้ว") { advanceToNextTerm() }
            }

            Picker("วิธีกรอกเทอมที่ผ่านมา", selection: $gpaxEntryMode) {
                Text("กรอกทีละเทอม").tag(GPAXSettings.EntryMode.perTerm)
                Text("กรอก GPAX สะสม").tag(GPAXSettings.EntryMode.cumulative)
            }

            if gpaxEntryMode == .cumulative {
                LabeledContent(
                    "GPAX สะสมที่กรอกไว้",
                    value: gpaxPriorGPAX > 0 ? String(format: "%.2f · %d เทอม", gpaxPriorGPAX, gpaxPriorTermCount) : "ยังไม่ได้กรอก"
                )
                Button("กรอก GPAX สะสม") { isPresentingCumulativeSheet = true }
            }

            NavigationLink {
                TermManagementView()
            } label: {
                LabeledContent("จัดการเทอม", value: "\(terms.count) เทอม")
            }

            NavigationLink("โหมดโฟกัส") { FocusModeView() }
        }
    }

    private var notificationSection: some View {
        Section("การแจ้งเตือน") {
            LabeledContent("สถานะสิทธิ์", value: authorizationStatusLabel)

            if notifications.authorizationStatus == .notDetermined {
                Button("ขอสิทธิ์แจ้งเตือน") {
                    Task { await notifications.requestAuthorization() }
                }
            }

            if notifications.authorizationStatus == .denied {
                Button("เปิดตั้งค่าแจ้งเตือนของเครื่อง") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            NavigationLink("การแจ้งเตือนที่ตั้งไว้") {
                PendingNotificationsView()
            }
        }
    }

    private var aboutSection: some View {
        Section("เกี่ยวกับแอป") {
            Button("ดูหน้าแนะนำแอปอีกครั้ง") { isPresentingWelcome = true }

            LabeledContent("เวอร์ชัน", value: "1.0.0 (Prototype)")
                .contentShape(Rectangle())
                .onTapGesture(perform: registerVersionTap)

            // Plain HStack, not LabeledContent: with a trailing closure the
            // compiler picks LabeledContent(content:label:) and reads the title
            // as the content view.
            HStack {
                Text("แผน")
                Spacer()
                if entitlements.hasPro || entitlements.hasPlus {
                    TierBadge(tier: entitlements.hasPlus ? .plus : .pro)
                } else {
                    Text("ฟรี").foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    /// Counts up to seven, then stops counting — tapping further does nothing.
    private func registerVersionTap() {
        guard !isShowingDeveloperTools else { return }
        versionTapCount += 1
        if versionTapCount >= 7 {
            isShowingDeveloperTools = true
            AppLog.action("Settings", "ปลดล็อกเครื่องมือนักพัฒนา")
        }
    }

    // MARK: - Developer tools
    //
    // Two locks, not one: `#if DEBUG` keeps this out of a release build, and
    // the seven-tap gate keeps it off screen during a demo — which runs from
    // Xcode and is therefore a debug build.
    //
    /// Kept out of `body` on purpose: `#if DEBUG` written inline inside a
    /// ViewBuilder confuses the type checker, so the conditional lives here
    /// and `body` just references the property.
    @ViewBuilder
    private var developerSection: some View {
        #if DEBUG
        if isShowingDeveloperTools {
            Section("สำหรับนักพัฒนา") {
                Toggle("เปิด Pro", isOn: $entitlements.hasPro)

                Button("เปิดหน้า Setup อีกครั้ง") { startSetupTest() }

                Button("ทดสอบแจ้งเตือน (5 วินาที)") {
                    Task {
                        await notifications.sendTestNotification()
                        showTestNotificationHint = true
                    }
                }

                NavigationLink("ทดสอบ OCR") { OCRDebugView() }

                Button("ลบข้อมูลทั้งหมดถาวร", role: .destructive) {
                    isConfirmingReset = true
                }
            } footer: {
                Text("กล่องนี้ไม่ขึ้นในเวอร์ชันจริง และซ่อนใหม่ทุกครั้งที่เปิดแอป")
                    .font(Theme.Font.caption)
            }
            // Attached here, not to `body`: SetupFlowTestContainer only exists
            // in a DEBUG build, so the reference has to live inside the #if too.
            .fullScreenCover(isPresented: $isPresentingSetupTest, onDismiss: restoreSetupFlags) {
                SetupFlowTestContainer()
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

    /// "ธน · ม.5 เทอม 1" — falls back to whichever half exists.
    private var profileSubtitle: String {
        let name = profile.nickname.isEmpty ? profile.firstName : profile.nickname
        let term = GPAXSettings.currentSortKey == nil ? "" : currentTermLabel
        return [name, term].filter { !$0.isEmpty }.joined(separator: " · ")
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
        deleteAll(PortfolioItem.self)
        deleteAll(PortfolioImage.self)
        PortfolioImageStore.deleteAll()
        deleteAll(CareerInterestResult.self)
        deleteAll(TCASScoreWeight.self)
        deleteAll(TCASScoreRecord.self)
        deleteAll(TCASSOP.self)
        deleteAll(TCASEntry.self)
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

        // การบล็อกแอปเป็นค่าระดับ**ระบบ** ไม่ได้อยู่ใน SwiftData — ถ้าไม่เคลียร์
        // ตรงนี้ ล้างข้อมูลแล้วแอปอื่นจะยังถูกบล็อกค้างอยู่
        PomodoroEngine.shared.stop(recordPartial: false)
        AppBlockManager.shared.stopBlocking(reason: "ล้างข้อมูลทั้งหมด")

        StudiiOSApp.seedBuiltInSubjects(in: context)

        hasCompletedOnboarding = false
        hasCompletedProfileSetup = false
        hasCompletedScheduleSetup = false
        hasCompletedGradeSetup = false
        hasCompletedSetupSummary = false
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        items.forEach { context.delete($0) }
    }

    /// Debug-only: temporarily marks every setup phase incomplete so the
    /// real Setup wizard (Profile → Schedule → Grade → Summary) can be
    /// clicked through again, without touching any SwiftData or profile
    /// data. The original flags are restored once the preview is dismissed.
    private func startSetupTest() {
        savedSetupFlags = (hasCompletedProfileSetup, hasCompletedScheduleSetup, hasCompletedGradeSetup, hasCompletedSetupSummary)
        hasCompletedProfileSetup = false
        hasCompletedScheduleSetup = false
        hasCompletedGradeSetup = false
        hasCompletedSetupSummary = false
        isPresentingSetupTest = true
    }

    private func restoreSetupFlags() {
        guard let saved = savedSetupFlags else { return }
        hasCompletedProfileSetup = saved.profile
        hasCompletedScheduleSetup = saved.schedule
        hasCompletedGradeSetup = saved.grade
        hasCompletedSetupSummary = saved.summary
        savedSetupFlags = nil
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
