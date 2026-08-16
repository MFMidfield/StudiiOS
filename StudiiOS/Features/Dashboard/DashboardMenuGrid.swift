//
//  DashboardMenuGrid.swift
//  "เมนูหลัก" 3-column grid — split out of DashboardView.swift so the
//  per-item press-scale gesture state doesn't bloat the root view's body.
//
//  Every tile shares one icon treatment (`primaryDeep` on `primarySoft`)
//  rather than a color per feature: six differently-colored squares read as
//  decoration, and it left `danger`/`warning`/`success` meaning nothing.
//

import SwiftUI

private struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let destination: DashboardDestination
    let tier: FeatureTier
}

struct DashboardMenuGrid: View {
    private let menuItems: [MenuItem] = [
        MenuItem(title: "ปฏิทิน", icon: "calendar", destination: .calendar, tier: .free),
        MenuItem(title: "ศูนย์เกรด", icon: "chart.bar", destination: .gradeCenter, tier: .free),
        MenuItem(title: "SOP", icon: "square.and.pencil", destination: .sop, tier: .free),
        MenuItem(title: "ผลงาน", icon: "folder", destination: .portfolio, tier: .free),
        MenuItem(title: "ค้นหาอาชีพ", icon: "briefcase", destination: .careerDiscovery, tier: .free),
        MenuItem(title: "โหมดโฟกัส", icon: "timer", destination: .focusMode, tier: .free),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
        GridItem(.flexible(), spacing: Theme.Spacing.md),
    ]

    var body: some View {
        CardContainer {
            SectionHeader("เมนูหลัก")
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.lg) {
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
        VStack(spacing: Theme.Spacing.sm) {
            ZStack(alignment: .topTrailing) {
                IconTile(systemName: item.icon, size: 52, cornerRadius: 16)
                if item.tier != .free {
                    TierBadge(tier: item.tier)
                        .offset(x: 8, y: -6)
                }
            }
            Text(item.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        DashboardMenuGrid()
            .padding()
            .background(Theme.Colors.background)
    }
}
