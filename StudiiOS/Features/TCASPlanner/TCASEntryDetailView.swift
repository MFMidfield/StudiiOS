//
//  TCASEntryDetailView.swift
//  หน้ารายละเอียด 1 คณะ — การ์ดคะแนน · การ์ด "ดันวิชาไหนคุ้มสุด" · น้ำหนักวิชา ·
//  SOP · ลิงก์ระเบียบการ · โน้ต
//
//  การ์ดคะแนนไม่ได้ถูกห่อด้วย NavigationLink อีกแล้ว: ปุ่มดินสอ (ตั้งเป้า) อยู่ในการ์ด
//  และปุ่มซ้อนใน label ของ NavigationLink กดไม่ติด — ทางไปตั้งน้ำหนักย้ายลงมาเป็นแถว
//  "น้ำหนักวิชา" ที่มองเห็นได้จริง แทนการซ่อนไว้ว่า "แตะการ์ดสิ"
//

import SwiftUI
import SwiftData

struct TCASEntryDetailView: View {
    @Bindable var entry: TCASEntry
    @Query private var records: [TCASScoreRecord]
    @Environment(\.openURL) private var openURL

    @State private var isEditingTarget = false

    private var weightInputs: [TCASWeightInput] {
        entry.weights.map {
            TCASWeightInput(examCode: $0.examCode, percent: $0.percent, groupName: $0.groupName, groupPercent: $0.groupPercent)
        }
    }

    private var scoreInputs: [TCASScoreInput] {
        records.map { TCASScoreInput(examCode: $0.examCode, score: $0.score, hasTaken: $0.hasTaken) }
    }

    private var ceiling: Double {
        TCASScoreEngine.ceilingScore(weights: weightInputs, scores: scoreInputs)
    }

    private var weightSummary: String {
        guard !entry.weights.isEmpty else { return "ยังไม่ตั้ง" }
        let total = TCASScoreEngine.totalPercent(weights: weightInputs)
        return "\(total.formatted(.number.precision(.fractionLength(0))))% · \(entry.weights.count) วิชา"
    }

    var body: some View {
        List {
            Section {
                TCASScoreCard(entry: entry, records: records) {
                    isEditingTarget = true
                }
                .cardRow()
                // การ์ด leverage คืน EmptyView เมื่อยังไม่มีน้ำหนัก — กันไม่ให้เหลือ
                // แถวเปล่าที่มีแต่ padding ค้างอยู่ใน List
                if !entry.weights.isEmpty {
                    TCASLeverageCard(entry: entry, records: records)
                        .cardRow()
                }
            }

            Section {
                NavigationLink {
                    TCASWeightSetupView(entry: entry)
                } label: {
                    HStack {
                        Label("น้ำหนักวิชา", systemImage: "percent")
                        Spacer()
                        Text(weightSummary)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                NavigationLink {
                    SOPEditorView(entry: entry)
                } label: {
                    HStack {
                        Label("SOP", systemImage: "doc.text")
                        Spacer()
                        Text(sopStatusText)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Section {
                TextEditor(text: $entry.notes)
                    .frame(minHeight: 100)
            } header: {
                Text("โน้ต")
            }

            // §0.3 กฎเหล็ก: แอปไม่เก็บเกณฑ์/คะแนนต่ำสุดของคณะไหนเลย — ทุกอย่างที่เป็น
            // ข้อมูลจริงส่งออกไป mytcas.com เสมอ
            Section {
                TextField("วางลิงก์ระเบียบการจาก mytcas ที่นี่ (ถ้ามี)", text: $entry.admissionURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    openMyTCAS()
                } label: {
                    Label("เปิดดูเกณฑ์ใน mytcas", systemImage: "safari")
                }
            } header: {
                Text("ระเบียบการ")
            }
        }
        .navigationTitle(entry.facultyName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingTarget) {
            TCASTargetSheet(entry: entry, ceiling: ceiling)
        }
    }

    private var sopStatusText: String {
        guard let sop = entry.sop else { return "ยังไม่เริ่ม" }
        return sop.isMerged ? "รวมแล้ว" : "ฉบับร่าง"
    }

    private func openMyTCAS() {
        let urlString = entry.admissionURL.isEmpty ? "https://www.mytcas.com" : entry.admissionURL
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}

private extension View {
    /// การ์ดที่ลอยอยู่ใน List — ถอดพื้นกับ inset ของแถวออกให้เหลือแค่การ์ด
    func cardRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.bottom, Theme.Spacing.md)
    }
}
