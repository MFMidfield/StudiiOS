//
//  RootTabView.swift
//  The app's 5-tab shell: หน้าแรก, งาน, Smart Capture, ตารางสอน, ตั้งค่า.
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

struct RootTabView: View {
    enum Tab: Hashable {
        case dashboard, tasks, capture, schedule, settings
    }

    @State private var selectedTab: Tab = .dashboard
    @State private var previousTab: Tab = .dashboard
    @State private var showCapture = false

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
                .tabItem { Label("ตารางสอน", systemImage: "calendar.day.timeline.leading") }
                .tag(Tab.schedule)

            NavigationStack { SettingsView() }
                .tabItem { Label("ตั้งค่า", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Theme.Colors.primary)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == .capture {
                previousTab = oldValue
                showCapture = true
                selectedTab = oldValue
            }
        }
        .sheet(isPresented: $showCapture) {
            QuickAddSheet()
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
