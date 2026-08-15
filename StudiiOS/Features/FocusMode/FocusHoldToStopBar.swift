//
//  FocusHoldToStopBar.swift
//  แถบบอกความคืบหน้าของการกดค้างเพื่อหยุด
//
//  ไม่บอกจำนวนวินาทีโดยตั้งใจ — ผู้ใช้แค่ต้องรู้ว่า "เต็มหลอดแล้วมันจะหยุด"
//

import SwiftUI

struct FocusHoldToStopBar: View {
    let progress: Double
    let isHolding: Bool

    private let width: CGFloat = 132
    private let height: CGFloat = 5

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(isHolding ? "ค้างไว้จนเต็ม" : "กดค้างที่ไหนก็ได้เพื่อหยุด")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Colors.onFocusBackdropMuted)
                .contentTransition(.opacity)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Colors.onFocusBackdrop.opacity(0.15))
                    .frame(width: width, height: height)

                Capsule()
                    .fill(Theme.Colors.primary)
                    .frame(width: width * min(1, max(0, progress)), height: height)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isHolding)
    }
}

#Preview {
    ZStack {
        Theme.Colors.focusBackdrop.ignoresSafeArea()
        FocusHoldToStopBar(progress: 0.4, isHolding: true)
    }
}
