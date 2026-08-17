//
//  CareerDiscoveryView.swift
//  Career Discovery hub — intro card that launches the 18-item RIASEC
//  screening inventory (RIASECQuizView), plus the latest result and a
//  short history, both pushing RIASECResultView. See PLAN_RIASEC.md §7.1.
//
//  Tier: Free (see PLAN_RIASEC.md §6.1 — no purchase flow exists yet, so
//  gating this would show every judge an upsell wall instead of the demo).
//  MARK: - Tier gate — wrap the start button in
//  `if EntitlementStore.shared.isUnlocked(.pro)` here if this becomes Pro-gated later.
//

import SwiftUI
import SwiftData

struct CareerDiscoveryView: View {
    @Query(sort: \CareerInterestResult.takenAt, order: .reverse) private var pastResults: [CareerInterestResult]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                introCard
                if let latest = pastResults.first {
                    latestResultCard(latest)
                }
                if pastResults.count > 1 {
                    historyCard
                }
            }
            .padding()
        }
        .navigationTitle("ค้นหาสายอาชีพที่ใช่")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introCard: some View {
        CardContainer {
            Text("ค้นหาสายอาชีพที่ใช่")
                .font(.title3.bold())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("18 คำถาม · ประมาณ 3 นาที · ไม่มีคำตอบถูกผิด · ทำงานแบบออฟไลน์ ไม่ส่งข้อมูลออกจากเครื่อง")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            NavigationLink(destination: RIASECQuizView()) {
                Text("เริ่มทำแบบสำรวจ")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.primary)
        }
    }

    @ViewBuilder
    private func latestResultCard(_ result: CareerInterestResult) -> some View {
        CardContainer {
            Text("ผลลัพธ์ล่าสุด").font(.subheadline).fontWeight(.semibold)
            // Both states share ResultSummaryRow — it already renders the
            // inconclusive case. A bespoke VStack here made the card shrink to
            // its text instead of filling the width like every other card.
            NavigationLink(destination: RIASECResultView(result: result)) {
                ResultSummaryRow(result: result)
            }
            .buttonStyle(.plain)
        }
    }

    private var historyCard: some View {
        CardContainer {
            Text("ประวัติการทำแบบสำรวจ").font(.subheadline).fontWeight(.semibold)
            ForEach(pastResults.dropFirst().prefix(5)) { past in
                NavigationLink(destination: RIASECResultView(result: past)) {
                    ResultSummaryRow(result: past)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One row: Holland code (or "ไม่ชัดเจน") + top dimension + date. Reused by
/// both the latest-result card and the history list.
private struct ResultSummaryRow: View {
    let result: CareerInterestResult

    private var topDimension: RIASECDimension? {
        result.hollandCode.first.flatMap { RIASECDimension(rawValue: String($0)) }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(result.isInconclusive ? "ไม่ชัดเจน" : result.hollandCode)
                    .font(.title3.bold())
                    .foregroundStyle(topDimension?.color ?? Theme.Colors.textPrimary)
                if let topDimension, !result.isInconclusive {
                    Text("\(topDimension.thaiName) \(result.riasecScores[topDimension] ?? 50)%")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Text(result.takenAt.thaiShortString)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

#Preview {
    NavigationStack { CareerDiscoveryView() }
        .modelContainer(for: CareerInterestResult.self, inMemory: true)
}
