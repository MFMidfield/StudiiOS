//
//  RootTabView.swift
//  The app's 5-tab shell: หน้าแรก, งาน, Smart Capture, ตารางเรียน, ตั้งค่า.
//  Each tab owns its own NavigationStack so feature modules can push detail
//  screens independently.
//
//  ปฏิทิน moved out of the tab bar and into the Dashboard menu — it's a
//  browse-when-you-need-it screen, while งาน is opened many times a day.
//

import SwiftUI

/// Destinations reachable from the Dashboard's main menu grid.
enum DashboardDestination: Hashable {
    case assignments
    case calendar
    case gradeCenter
    case tcasPlanner
    case portfolio
    case careerDiscovery
    case focusMode
}

/// Which screen the quick-add flow starts on. `.menu` is the full "เพิ่มอะไรดี?"
/// grid; every other case jumps straight to a form.
enum QuickAddTarget: String, Identifiable, CaseIterable {
    case menu, task, event, scheduleEntry, portfolio

    var id: String { rawValue }
}

struct RootTabView: View {
    enum Tab: Hashable {
        case dashboard, tasks, capture, schedule, settings
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var previousTab: Tab = .dashboard
    @State private var showCapture = false
    @State private var quickAddStart: QuickAddTarget = .menu

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
                    .navigationDestination(for: DashboardDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
            .tabItem { Label("หน้าแรก", systemImage: "house.fill") }
            .tag(Tab.dashboard)

            NavigationStack { AssignmentListView() }
                .tabItem { Label("งาน", systemImage: "checklist") }
                .tag(Tab.tasks)

            Color.clear
                .tabItem { Label("เพิ่ม", systemImage: "plus.circle.fill") }
                .tag(Tab.capture)

            NavigationStack { ScheduleView() }
                .tabItem { Label("ตารางเรียน", systemImage: "calendar.day.timeline.leading") }
                .tag(Tab.schedule)

            NavigationStack { SettingsView() }
                .tabItem { Label("ตั้งค่า", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.Colors.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .capture {
                previousTab = oldValue
                quickAddStart = quickAddTarget(for: oldValue)
                showCapture = true
                selectedTab = oldValue
            }
        }
        .sheet(isPresented: $showCapture) {
            QuickAddFlow(start: quickAddStart)
        }
    }

    /// The "+" button adds whatever the tab you're standing on is about; the
    /// menu is only for tabs with no obvious answer.
    ///
    /// Screens pushed from the Dashboard menu still count as หน้าแรก — teaching
    /// child screens to announce their own kind needs a PreferenceKey (W3).
    private func quickAddTarget(for tab: Tab) -> QuickAddTarget {
        switch tab {
        case .tasks: return .task
        case .schedule: return .scheduleEntry
        case .dashboard, .settings, .capture: return .menu
        }
    }

    @ViewBuilder
    private func destinationView(for destination: DashboardDestination) -> some View {
        switch destination {
        case .assignments: AssignmentListView()
        case .calendar: CalendarView()
        case .gradeCenter: GradeCenterView()
        case .tcasPlanner: TCASPlannerView()
        case .portfolio: PortfolioView()
        case .careerDiscovery: CareerDiscoveryView()
        case .focusMode: FocusModeView()
        }
    }
}

#Preview {
    RootTabView()
}
