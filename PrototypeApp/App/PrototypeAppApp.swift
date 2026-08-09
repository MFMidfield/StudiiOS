//
//  PrototypeAppApp.swift
//  Student OS — offline-first student life app.
//
//  App entry point: builds the shared SwiftData container covering every
//  feature module's models (see Core/Models) and launches RootTabView.
//

import SwiftUI
import SwiftData

@main
struct PrototypeAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Assignment.self,
            Note.self,
            Flashcard.self,
            GradeComponent.self,
            ExamEvent.self,
            ScheduleEntry.self,
            FocusSession.self,
            PortfolioItem.self,
            PortfolioImage.self,
            CareerInterestResult.self,
            TCASEntry.self,
            TCASChecklistItem.self,
            SemesterRecord.self,
            CalendarEvent.self,
            CalendarTag.self,
            CalendarAttachmentItem.self,
            Subject.self,
            DayScheduleOverride.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        _ = NotificationManager.shared
        PrototypeAppApp.seedBuiltInSubjects(in: sharedModelContainer.mainContext)
    }

    /// Seeds the 3 built-in subjects (club, uniform activity, lunch break) on
    /// first launch, or after `resetAllData()` wipes the store. Safe to call
    /// repeatedly — it's a no-op once any Subject exists.
    static func seedBuiltInSubjects(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Subject>())) ?? []
        guard existing.isEmpty else { return }

        let builtIns: [(name: String, colorHex: String, iconName: String, isBreak: Bool)] = [
            ("ชุมนุม", "9C27B0", "person.3.fill", false),
            ("กิจกรรมในเครื่องแบบ", "3F51B5", "figure.hiking", false),
            ("พักกลางวัน", "FFB347", "fork.knife", true),
        ]
        for builtIn in builtIns {
            context.insert(Subject(
                name: builtIn.name,
                colorHex: builtIn.colorHex,
                iconName: builtIn.iconName,
                isBreak: builtIn.isBreak,
                isBuiltIn: true
            ))
        }
        try? context.save()
        AppLog.action("Subject", "seed วิชาเริ่มต้น 3 รายการ")
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Switches between the first-launch WelcomeView and the main RootTabView.
private struct RootContainerView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    @AppStorage("hasCompletedScheduleSetup") private var hasCompletedScheduleSetup = false
    @AppStorage("hasCompletedGradeSetup") private var hasCompletedGradeSetup = false
    @AppStorage("hasCompletedSetupSummary") private var hasCompletedSetupSummary = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [Assignment]

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                WelcomeView()
            } else if !hasCompletedProfileSetup {
                ProfileSetupView()
            } else if !hasCompletedScheduleSetup {
                NavigationStack { ScheduleSetupView() }
            } else if !hasCompletedGradeSetup {
                NavigationStack { GradeReportSetupView() }
            } else if !hasCompletedSetupSummary {
                SetupSummaryView()
            } else {
                RootTabView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // ป้ายวัน ("พรุ่งนี้"/"วันนี้") และหน้าต่าง 14 วัน ขึ้นกับวันที่ปัจจุบัน
            // จึงต้องกวาดตั้งใหม่ทุกครั้งที่กลับเข้าแอป
            guard newPhase == .active else { return }
            Task { await NotificationManager.shared.refreshAssignmentReminders(assignments) }

            // กันแอปอื่นถูกบล็อกค้าง: ถ้าเซสชันโฟกัสหมดเวลาไปแล้ว (หรือผู้ใช้
            // บังคับปิดแอปทิ้งไว้) ต้องปลดบล็อกให้ตั้งแต่เปิดแอปมา ไม่ใช่รอ
            // ให้ผู้ใช้เดินเข้าหน้าโฟกัสก่อน
            PomodoroEngine.shared.attach(context: modelContext)
            PomodoroEngine.shared.syncToNow()
            AppBlockManager.shared.reconcile()
        }
    }
}
