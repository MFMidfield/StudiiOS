//
//  DashboardMenuGrid.swift
//  "เมนูหลัก" 2×3 grid — split out of DashboardView.swift so the per-item
//  press-scale gesture state doesn't bloat the root view's body.
//

import SwiftUI

private struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: DashboardDestination
    let tier: FeatureTier
}

struct DashboardMenuGrid: View {
    private let menuItems: [MenuItem] = [
        MenuItem(title: "เกรด & GPA", subtitle: "ติดตามผลการเรียน", icon: "chart.bar.fill", color: Theme.Colors.primary, destination: .gradeCenter, tier: .free),
        MenuItem(title: "TCAS Planner", subtitle: "วางแผนสอบเข้า", icon: "target", color: Theme.Colors.info, destination: .tcasPlanner, tier: .free),
        MenuItem(title: "Portfolio", subtitle: "รวบรวมผลงาน", icon: "folder.fill", color: Theme.Colors.success, destination: .portfolio, tier: .free),
        MenuItem(title: "Career", subtitle: "สำรวจอาชีพ", icon: "briefcase.fill", color: Theme.Colors.warning, destination: .careerDiscovery, tier: .free),
        MenuItem(title: "งาน / การบ้าน", subtitle: "รายการงาน", icon: "checkmark.square.fill", color: Theme.Colors.info, destination: .assignments, tier: .free),
        MenuItem(title: "โฟกัส", subtitle: "Pomodoro Timer", icon: "timer", color: Theme.Colors.indigo, destination: .focusMode, tier: .free),
    ]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        CardContainer {
            Text("เมนูหลัก")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textPrimary)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(menuItems) { item in
                    NavigationLink(value: item.destination) {
                        MenuItemView(item: item)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
    }
}

private struct MenuItemView: View {
    let item: MenuItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(item.color.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: item.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(item.color)
                }
                if item.tier != .free {
                    TierBadge(tier: item.tier)
                        .offset(x: 8, y: -6)
                }
            }
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        DashboardMenuGrid()
            .padding()
    }
}
