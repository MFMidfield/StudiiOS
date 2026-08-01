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
            CareerInterestResult.self,
            TCASEntry.self,
            TCASChecklistItem.self,
            SemesterRecord.self,
            CalendarEvent.self,
            CalendarTag.self,
            CalendarAttachmentItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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

    var body: some View {
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
}
