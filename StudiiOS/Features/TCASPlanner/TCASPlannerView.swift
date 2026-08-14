//
//  TCASPlannerView.swift
//  TCAS Planner (Free feature): บันทึกคณะ/มหาวิทยาลัยที่สนใจ + ระบบคิดคะแนนย้อนกลับ
//  + SOP ต่อคณะ · ทุกจุดคะแนน/เกณฑ์การรับจริงเปิด mytcas.com แทนเก็บเอง (§0.3 กฎเหล็ก)
//
//  ลิสต์เป็นการ์ดที่บอกคะแนนของทุกคณะในจอเดียว (06_TCAS §4.1) — ยังเป็น List
//  เพราะปัดซ้ายลบต้องใช้ได้อยู่ แค่ถอด chrome ของ List ออกให้การ์ดลอยบนพื้นหน้า
//

import SwiftUI
import SwiftData

struct TCASPlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TCASEntry.sortOrder) private var entries: [TCASEntry]
    @Query private var records: [TCASScoreRecord]

    @State private var isPresentingNew = false
    @State private var isConfirmingDelete = false
    @State private var pendingDelete: TCASEntry?

    private var filledCount: Int { records.filter(\.hasTaken).count }

    var body: some View {
        List {
            Section { myScoresCard }
            if !entries.isEmpty {
                Section { entryCards } header: { entriesHeader }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("วางแผน TCAS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { addButton }
        }
        .overlay { emptyState }
        .sheet(isPresented: $isPresentingNew) {
            NewTCASEntrySheet()
        }
        // ลบคณะ = ลบน้ำหนักกับ SOP ไปด้วย (cascade) — ของที่พิมพ์เองหายทั้งหมด
        // จึงต้องถามก่อน ไม่ใช่ลบทันทีเหมือนเดิม
        .alert("ลบคณะนี้?", isPresented: $isConfirmingDelete, presenting: pendingDelete) { entry in
            Button("ลบ", role: .destructive) { delete(entry) }
            Button("ยกเลิก", role: .cancel) { pendingDelete = nil }
        } message: { entry in
            Text("\(entry.facultyName) — \(entry.universityName)\nน้ำหนักวิชาและ SOP ที่เขียนไว้จะถูกลบไปด้วย กู้คืนไม่ได้")
        }
    }

    // MARK: - คะแนนสอบของฉัน

    private var myScoresCard: some View {
        NavigationLink {
            MyScoresView()
        } label: {
            CardContainer(padding: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    IconTile(systemName: "chart.bar.doc.horizontal", size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("คะแนนสอบของฉัน")
                            .font(Theme.Font.plex(15, .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("กรอกแล้ว \(filledCount) จาก \(TCASExamCatalog.all.count) วิชา")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .plainRow()
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.md)
    }

    // MARK: - คณะเป้าหมาย

    private var entriesHeader: some View {
        Text("คณะเป้าหมาย \(entries.count) คณะ")
            .font(Theme.Font.plex(13, .semibold))
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.background)
            .listRowInsets(EdgeInsets())
    }

    private var entryCards: some View {
        ForEach(entries) { entry in
            NavigationLink {
                TCASEntryDetailView(entry: entry)
            } label: {
                TCASEntryCard(entry: entry, records: records)
            }
            .buttonStyle(.plain)
            .plainRow()
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDelete = entry
                    isConfirmingDelete = true
                } label: {
                    Label("ลบ", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Toolbar

    /// ＋ เปล่าๆ แบบเดียวกับหน้างานและตารางเรียน (Few 15 ส.ค. — ล้มข้อ "ปุ่มมีพื้น
    /// + คณะ" ใน 06_TCAS §4.1) ทุกหน้าในแอปจึงใช้ปุ่มเพิ่มหน้าตาเดียวกันหมด
    private var addButton: some View {
        Button {
            isPresentingNew = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("เพิ่มคณะเป้าหมาย")
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label("ยังไม่มีคณะเป้าหมาย", systemImage: "building.columns")
            } description: {
                Text("เพิ่มคณะที่อยากเข้า แล้วกรอกน้ำหนัก % ของแต่ละวิชา แอปจะคำนวณให้ว่าต้องได้อีกเท่าไรถึงจะถึงเป้า")
            } actions: {
                Button("เพิ่มคณะแรก") { isPresentingNew = true }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.Colors.primary)
            }
        }
    }

    // MARK: - Data

    private func delete(_ entry: TCASEntry) {
        context.delete(entry)
        pendingDelete = nil
    }
}

// MARK: - Row styling helper

private extension View {
    /// ถอด chrome ของ List ออกเพื่อให้การ์ดลอยบนพื้นหน้า (แบบเดียวกับหน้างาน)
    func plainRow() -> some View {
        self
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }
}

#Preview {
    NavigationStack { TCASPlannerView() }
        .modelContainer(for: [TCASEntry.self, TCASScoreWeight.self, TCASScoreRecord.self, TCASSOP.self], inMemory: true)
}
