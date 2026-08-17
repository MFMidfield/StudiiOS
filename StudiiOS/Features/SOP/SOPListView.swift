//
//  SOPListView.swift
//  หน้า "SOP" — คณะที่ตั้งใจยื่นทั้งหมด เข้าจากเมนูหน้าแรก
//
//  แทนที่ `TCASPlannerView` (16 ส.ค. 2569): ตัดการ์ด "คะแนนสอบของฉัน" ·
//  น้ำหนักวิชา · เป้าคะแนน ออกหมด เหลือลิสต์คณะ + ทางไปเขียน SOP
//

import SwiftUI
import SwiftData

struct SOPListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SOPTarget.sortOrder) private var targets: [SOPTarget]

    @State private var isPresentingNew = false
    @State private var isConfirmingDelete = false
    @State private var pendingDelete: SOPTarget?

    var body: some View {
        content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationTitle("SOP")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { addButton }
        }
        .sheet(isPresented: $isPresentingNew) {
            NewSOPTargetSheet()
        }
        // ลบคณะ = SOP ที่เขียนไว้หายไปด้วย (cascade) จึงต้องถามก่อนเสมอ
        .alert("ลบคณะนี้?", isPresented: $isConfirmingDelete, presenting: pendingDelete) { target in
            Button("ลบ", role: .destructive) { delete(target) }
            Button("ยกเลิก", role: .cancel) { pendingDelete = nil }
        } message: { target in
            Text("\(target.universityName) — \(target.facultyLine)\nSOP ที่เขียนไว้จะถูกลบไปด้วย กู้คืนไม่ได้")
        }
    }

    /// ⚠️ ยังไม่มีคณะ = วาด `ContentUnavailableView` **แทน** ScrollView ไม่ใช่ `.overlay` ทับ
    /// ScrollView ที่เนื้อหาว่าง — ScrollView ที่ไม่มีเนื้อหาหดเหลือความกว้างเท่า padding
    /// แล้ว overlay ก็หดตาม (ข้อความไทยเลยเรียงลงมาทีละตัว)
    @ViewBuilder
    private var content: some View {
        if targets.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(targets) { target in
                        NavigationLink {
                            SOPEditorView(target: target)
                        } label: {
                            SOPTargetCard(target: target)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("ลบคณะนี้", systemImage: "trash", role: .destructive) {
                                pendingDelete = target
                                isConfirmingDelete = true
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.lg)
            }
        }
    }

    private var addButton: some View {
        Button {
            isPresentingNew = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("เพิ่มคณะที่อยากยื่น")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ยังไม่มีคณะที่จะยื่น", systemImage: "graduationcap")
        } description: {
            Text("ใส่มหาวิทยาลัย คณะ และสาขาที่อยากเข้า\nแล้วเขียน SOP ของที่นั่นได้ในแอปเลย")
        } actions: {
            Button("เพิ่มคณะแรก") { isPresentingNew = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func delete(_ target: SOPTarget) {
        context.delete(target)
        try? context.save()
        pendingDelete = nil
        AppLog.action("SOP", "ลบคณะ: \(target.universityName) · \(target.facultyLine)")
    }
}

#Preview {
    NavigationStack { SOPListView() }
        .modelContainer(for: [SOPTarget.self, SOPDocument.self], inMemory: true)
}
