//
//  RootTabView.swift
//  The app's 5-tab shell: Dashboard, ปฏิทิน, Smart Capture,
//  ตารางเรียน, Settings. Each tab owns its own NavigationStack so
//  feature modules can push detail screens independently.
//

import SwiftUI

/// Destinations reachable from the Dashboard's main menu grid.
enum DashboardDestination: Hashable {
    case assignments
    case gradeCenter
    case tcasPlanner
    case portfolio
    case careerDiscovery
    case focusMode
}

struct RootTabView: View {
    enum Tab: Hashable {
        case dashboard, calendar, capture, schedule, settings
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

            NavigationStack { CalendarView() }
                .tabItem { Label("ปฏิทิน", systemImage: "calendar") }
                .tag(Tab.calendar)

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
