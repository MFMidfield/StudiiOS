//
//  PortfolioSetupView.swift
//  หน้า 5 ของ setup — เริ่มเก็บผลงานตั้งแต่วันนี้
//
//  ใช้ `PortfolioItemSheet` ตัวเดียวกับแท็บผลงาน ไม่มีฟอร์มย่อเฉพาะ setup:
//  ฟอร์มย่อจะเก็บได้ไม่ครบแล้วผู้ใช้ต้องกลับมาเติมทีหลังทุกชิ้น
//
//  ปุ่มล่างเปลี่ยนตามสถานะตามสเปค — ยังไม่มีของ = "ข้าม" · มีแล้ว = "ถัดไป"
//

import SwiftUI
import SwiftData

struct PortfolioSetupView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    @Query(sort: \PortfolioItem.startDate, order: .reverse) private var items: [PortfolioItem]
    @State private var isAddingItem = false

    var body: some View {
        OnboardingScaffold(
            step: .portfolio,
            onBack: onBack,
            primaryTitle: items.isEmpty ? "ยังไม่มี ข้ามไปก่อน" : "ถัดไป",
            onPrimary: onNext
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                addButton
                if items.isEmpty {
                    hint
                } else {
                    itemList
                }
            }
        }
        .sheet(isPresented: $isAddingItem) {
            PortfolioItemSheet(mode: .create)
        }
    }

    // MARK: - Pieces

    private var addButton: some View {
        Button {
            isAddingItem = true
        } label: {
            CardContainer {
                HStack(spacing: Theme.Spacing.lg) {
                    IconTile(systemName: "plus", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("เพิ่มผลงาน")
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("เกียรติบัตร · กิจกรรม · จิตอาสา · การแข่งขัน · โปรเจกต์")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var hint: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text("ยังไม่มีตอนนี้ก็ข้ามได้ เพิ่มทีหลังจากปุ่ม ＋ กลางแถบล่างได้ตลอด — แต่คนที่เก็บตั้งแต่ ม.4 จะไม่ต้องมานั่งไล่หาเกียรติบัตรตอนทำ Portfolio ยื่น TCAS")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var itemList: some View {
        OnboardingSection(title: "เพิ่มแล้ว \(items.count) ชิ้น") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { item in
                    itemRow(item)
                }
            }
        }
    }

    private func itemRow(_ item: PortfolioItem) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            IconTile(systemName: item.category.icon, color: item.category.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(Theme.Font.plex(14, .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(item.category.label)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
    }
}
