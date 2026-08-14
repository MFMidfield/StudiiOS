//
//  SectionHeader.swift
//  Title row that opens a section, with an optional trailing affordance
//  (usually a "ดูทั้งหมด" link into the full list).
//

import SwiftUI

struct SectionHeader<Trailing: View>: View {
    private let title: String
    private let systemImage: String?
    private let trailing: Trailing

    init(_ title: String, systemImage: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
            Text(title)
                .font(Theme.Font.heading)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer(minLength: Theme.Spacing.sm)

            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, systemImage: String? = nil) {
        self.init(title, systemImage: systemImage, trailing: { EmptyView() })
    }
}

/// Standard look for a section's trailing affordance. Wrap it in whatever
/// actually navigates — `NavigationLink { SectionMoreLabel() }` or a `Button`.
struct SectionMoreLabel: View {
    var title: String = "ดูทั้งหมด"

    var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .font(Theme.Font.plex(13, .medium))
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Theme.Colors.primaryDeep)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
        SectionHeader("งานที่ต้องส่ง")

        SectionHeader("งานที่ต้องส่ง", systemImage: "checklist") {
            SectionMoreLabel()
        }

        SectionHeader("เมนูหลัก", systemImage: "square.grid.2x2") {
            PillLabel("7 รายการ", tone: .accent)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.Colors.background)
}
