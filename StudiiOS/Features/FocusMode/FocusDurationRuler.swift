//
//  FocusDurationRuler.swift
//  ไม้บรรทัดเลือกเวลาแบบเลื่อนซ้ายขวา
//
//  ค่าที่เลือกได้: `0` = ∞ (ซ้ายสุด) แล้ว 1…180 ทีละ 1 นาที
//  ขีดยาว + ตัวเลขทุก 5 นาที · ตัวเลขกำกับทุก 15 นาที (แน่นกว่านี้อ่านไม่ออก)
//
//  ใช้ `scrollPosition(id:)` + `.scrollTargetBehavior(.viewAligned)` แทนการคำนวณ
//  offset เอง — ระบบจัดการ snap/โมเมนตัม/การชนขอบให้หมด และค่าที่ได้คือ id ของขีด
//  ที่หยุดตรงกลางพอดี ไม่ต้องหารระยะทางเอง
//

import SwiftUI

struct FocusDurationRuler: View {
    /// `0` = ∞
    @Binding var minutes: Int

    private let tickWidth: CGFloat = 16
    private let values = Array(PomodoroSettings.minuteRange)

    @State private var scrolledValue: Int?

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        tick(for: value)
                            .frame(width: tickWidth)
                            .id(value)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, max(0, (geo.size.width - tickWidth) / 2))
            .scrollPosition(id: $scrolledValue, anchor: .center)
            .scrollTargetBehavior(.viewAligned)
            .mask(edgeFade)
            .overlay(needle)
        }
        .frame(height: 84)
        .sensoryFeedback(.selection, trigger: minutes)
        .onAppear { scrolledValue = minutes }
        .onChange(of: scrolledValue) { _, newValue in
            guard let newValue, newValue != minutes else { return }
            minutes = newValue
        }
        .onChange(of: minutes) { _, newValue in
            guard scrolledValue != newValue else { return }
            scrolledValue = newValue
        }
    }

    // MARK: - ชิ้นส่วน

    private func tick(for value: Int) -> some View {
        let isMajor = value == 0 || value % 5 == 0
        let isSelected = value == minutes

        return VStack(spacing: Theme.Spacing.sm) {
            Capsule()
                .fill(tickColor(isSelected: isSelected, isMajor: isMajor))
                .frame(width: 2, height: isMajor ? 28 : 15)
                .frame(height: 30, alignment: .center)

            Group {
                if value == 0 {
                    Text("∞")
                } else if value % 15 == 0 {
                    Text("\(value)")
                } else {
                    Text(" ")
                }
            }
            .font(Theme.Font.caption)
            .foregroundStyle(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.textSecondary)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func tickColor(isSelected: Bool, isMajor: Bool) -> Color {
        if isSelected { return Theme.Colors.primaryDeep }
        return isMajor ? Theme.Colors.textSecondary : Theme.Colors.separator
    }

    /// เข็มกลาง — ตำแหน่งที่ค่าถูกเลือก
    private var needle: some View {
        Capsule()
            .fill(Theme.Colors.primary)
            .frame(width: 3, height: 40)
            .offset(y: -13)
            .allowsHitTesting(false)
    }

    /// จางที่ขอบซ้าย/ขวา ให้ดูเหมือนไม้บรรทัดไหลออกนอกจอ
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.12),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

#Preview {
    @Previewable @State var minutes = 25
    FocusDurationRuler(minutes: $minutes)
        .padding()
        .background(Theme.Colors.background)
}
