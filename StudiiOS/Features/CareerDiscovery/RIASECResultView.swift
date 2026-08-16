//
//  RIASECResultView.swift
//  Renders a RIASECProfile fresh off the quiz, or a saved CareerInterestResult
//  row from history — both funnel into the same small display model so the
//  layout code doesn't duplicate. See PLAN_RIASEC.md §7.3.
//

import SwiftUI

private struct RIASECResultData {
    let percentages: [RIASECDimension: Int]
    let ranked: [RIASECDimension]
    let hollandCode: String
    let isInconclusive: Bool
    let isBorderline: Bool
}

struct RIASECResultView: View {
    private let data: RIASECResultData

    init(profile: RIASECProfile) {
        data = RIASECResultData(
            percentages: profile.percentages,
            ranked: profile.ranked,
            hollandCode: profile.hollandCode,
            isInconclusive: profile.isInconclusive,
            isBorderline: profile.isBorderline
        )
    }

    init(result: CareerInterestResult) {
        let percentages = result.riasecScores
        let ranked = RIASECDimension.allCases.sorted { a, b in
            let percentA = percentages[a] ?? 50, percentB = percentages[b] ?? 50
            if percentA != percentB { return percentA > percentB }
            return RIASECDimension.allCases.firstIndex(of: a)! < RIASECDimension.allCases.firstIndex(of: b)!
        }
        let isBorderline = !result.isInconclusive && (percentages[ranked[0]] ?? 50) - (percentages[ranked[2]] ?? 50) < 8
        data = RIASECResultData(
            percentages: percentages,
            ranked: ranked,
            hollandCode: result.hollandCode,
            isInconclusive: result.isInconclusive,
            isBorderline: isBorderline
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if data.isInconclusive {
                    inconclusiveCard
                } else {
                    headerCard
                    topThreeCard
                }
                allSixCard
                if !data.isInconclusive {
                    facultyCard
                }
                linkOutButton
                disclaimer
                retakeButton
            }
            .padding()
        }
        .navigationTitle("ผลการสำรวจ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        CardContainer {
            Text(data.hollandCode)
                .font(.largeTitle.bold())
                .foregroundStyle(data.ranked[0].color)
            Text(data.ranked.prefix(3).map(\.thaiName).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
            if data.isBorderline {
                Text("อันดับ 1–3 คะแนนใกล้เคียงกันมาก ลองพิจารณาทั้งสามด้านควบคู่กัน")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var topThreeCard: some View {
        CardContainer {
            Text("3 อันดับแรกที่เข้ากับคุณ").font(.subheadline).fontWeight(.semibold)
            ForEach(data.ranked.prefix(3), id: \.self) { dim in
                BarRow(dimension: dim, percent: data.percentages[dim] ?? 50, style: .large)
            }
        }
    }

    private var allSixCard: some View {
        CardContainer {
            Text("ความเข้ากันครบทั้ง 6 ด้าน").font(.subheadline).fontWeight(.semibold)
            ForEach(data.ranked, id: \.self) { dim in
                BarRow(dimension: dim, percent: data.percentages[dim] ?? 50, style: .small)
            }
        }
    }

    private var facultyCard: some View {
        CardContainer {
            Text("คณะที่น่าสนใจ").font(.subheadline).fontWeight(.semibold)
            FacultySection(dimension: data.ranked[0])
            if data.ranked.count > 1 {
                let second = data.ranked[1]
                if (data.percentages[data.ranked[0]] ?? 50) - (data.percentages[second] ?? 50) <= 10 {
                    Divider()
                    FacultySection(dimension: second)
                }
            }
        }
    }

    // A destination link, not `NavigationLink(value:)` — the value form relies on
    // RootTabView's `navigationDestination`, which was pushing the wrong screen
    // from here.
    private var linkOutButton: some View {
        NavigationLink(destination: GradeCenterView()) {
            Text("ดูเกรดของฉัน")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.Colors.primary)
    }

    private var disclaimer: some View {
        Text("""
        ผลลัพธ์นี้เป็นเพียงจุดเริ่มต้นในการทำความรู้จักตัวเองเพื่อสำรวจคณะที่ใช่
        ความสนใจของคนเราเปลี่ยนแปลงและเติบโตได้เสมอ แนะนำให้ใช้เป็นแนวทางในการ
        ลองทำกิจกรรมที่หลากหลาย และปรึกษาครูแนะแนวควบคู่กันไป
        """)
        .font(.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    private var retakeButton: some View {
        NavigationLink(destination: RIASECQuizView()) {
            Text("ทำแบบสำรวจอีกครั้ง")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.bordered)
        .tint(Theme.Colors.primary)
    }

    private var inconclusiveCard: some View {
        CardContainer {
            Text("ผลยังไม่ชัดเจนพอ")
                .font(.title3.bold())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("คำตอบของคุณค่อนข้างใกล้เคียงกันทุกด้าน ซึ่งเป็นเรื่องปกติมาก — หลายคนสนใจหลายอย่างพอๆ กัน\nลองทำใหม่โดยเลือกคำตอบให้ต่างกันมากขึ้นตามความรู้สึกจริง หรือลองทำกิจกรรมใหม่ๆ แล้วกลับมาทำอีกครั้ง")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

private struct FacultySection: View {
    let dimension: RIASECDimension

    var body: some View {
        if let mapping = FacultyMappingTable.all[dimension] {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(dimension.groupName, systemImage: dimension.symbolName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(dimension.color)
                Text(mapping.faculties.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("วิชาที่ควรเน้น: \(mapping.focusSubjects.joined(separator: " · "))")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}

private struct BarRow: View {
    enum Style { case large, small }

    let dimension: RIASECDimension
    let percent: Int
    let style: Style

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: dimension.symbolName)
                .foregroundStyle(dimension.color)
                .frame(width: 20)
            Text(dimension.thaiName)
                .font(style == .large ? .subheadline : .caption)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: style == .large ? 90 : 76, alignment: .leading)
            BarTrack(percent: percent, color: dimension.color)
                .frame(height: style == .large ? 10 : 6)
            Text("\(percent)%")
                .font(style == .large ? .subheadline.weight(.semibold) : .caption2)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dimension.thaiName) \(percent) เปอร์เซ็นต์")
    }
}

private struct BarTrack: View {
    let percent: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.separator)
                Capsule().fill(color)
                    .frame(width: geo.size.width * CGFloat(percent) / 100)
            }
        }
        .accessibilityHidden(true)
    }
}
