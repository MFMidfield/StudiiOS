//
//  SOPGuideSheet.swift
//  คำแนะนำการเขียน SOP 13 หน้า — TabView(.page) ปัดซ้ายขวา + page dots (§6.1)
//  เปิดจากลิสต์หัวข้อท้ายหน้า SOPEditorView โดยเริ่มที่หน้าที่กด แล้วปัดต่อไปหน้าอื่นได้
//

import SwiftUI

struct SOPGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int

    init(startPage: Int) {
        _currentPage = State(initialValue: startPage)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentPage) {
                ForEach(SOPGuideContent.pages) { page in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text(page.title)
                                .font(Theme.Font.plex(20, .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(page.body)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.lg)
                    }
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .navigationTitle("คำแนะนำการเขียน SOP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
    }
}
