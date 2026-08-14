//
//  DashboardStatsCard.swift
//  "การเรียนวันนี้" summary — focus minutes + pending task count.
//  Split out of DashboardView.swift during the dark-mode/redesign pass so
//  the numeric roll animation (`.numericText()`) lives with its own state.
//

import SwiftUI

private struct StatItem: Identifiable {
    let id: String
    let value: Int
    let suffix: String
    let label: String
    let icon: String
    let color: Color
}

struct DashboardStatsCard: View {
    let focusMinutesToday: Int
    let pendingCount: Int

    private var stats: [StatItem] {
        [
            StatItem(id: "focus", value: focusMinutesToday, suffix: " น.", label: "โฟกัสวันนี้", icon: "timer", color: Theme.Colors.warning),
            StatItem(id: "pending", value: pendingCount, suffix: "", label: "งานค้าง", icon: "checkmark.seal.fill", color: Theme.Colors.success),
        ]
    }

    var body: some View {
        CardContainer {
            Text("การเรียนวันนี้")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(stats) { stat in
                    StatItemView(stat: stat)
                }
            }
        }
    }
}

private struct StatItemView: View {
    let stat: StatItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stat.color.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: stat.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(stat.color)
            }
            Text("\(stat.value)\(stat.suffix)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
                .animation(.snappy, value: stat.value)
            Text(stat.label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DashboardStatsCard(focusMinutesToday: 45, pendingCount: 3)
        .padding()
}
