//
//  PortfolioSummaryCard.swift
//  Top-of-screen summary for PortfolioView: total count, latest entry date, one
//  proportion bar split by category, and a legend. Only shown while the whole
//  portfolio is on screen — once a category filter is on, the proportions of a
//  single category carry no information.
//

import SwiftUI

struct PortfolioSummaryCard: View {
    let items: [PortfolioItem]

    private var breakdown: [(category: PortfolioCategory, count: Int)] {
        PortfolioCategory.allCases.compactMap { category in
            let count = items.filter { $0.category == category }.count
            return count > 0 ? (category, count) : nil
        }
    }

    private var latestDate: Date? {
        items.map(\.startDate).max()
    }

    var body: some View {
        CardContainer {
            header
            proportionBar
            legend
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("ทั้งหมด \(items.count) ชิ้น")
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
            Spacer()
            if let latestDate {
                Text("ล่าสุด \(latestDate.thaiShortNoYearString)")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var proportionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(breakdown, id: \.category) { entry in
                    Capsule()
                        .fill(entry.category.color)
                        .frame(width: width(for: entry.count, in: geo.size.width))
                }
            }
        }
        .frame(height: 7)
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 108), spacing: Theme.Spacing.sm, alignment: .leading)],
            alignment: .leading,
            spacing: Theme.Spacing.xs
        ) {
            ForEach(breakdown, id: \.category) { entry in
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(entry.category.color)
                        .frame(width: 7, height: 7)
                    Text(entry.category.label)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("\(entry.count)")
                        .font(Theme.Font.plex(13, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
    }

    /// Each segment keeps a 6pt floor so a single-item category stays visible.
    private func width(for count: Int, in totalWidth: CGFloat) -> CGFloat {
        let total = items.count
        guard total > 0, totalWidth > 0 else { return 0 }
        let gaps = CGFloat(max(breakdown.count - 1, 0)) * 2
        let usable = max(totalWidth - gaps, 0)
        return max(usable * CGFloat(count) / CGFloat(total), 6)
    }
}

#Preview {
    PortfolioSummaryCard(items: [])
        .padding()
        .background(Theme.Colors.background)
}
