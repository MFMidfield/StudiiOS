//
//  TCASEntryDetailView.swift
//  หน้ารายละเอียด 1 คณะ — การ์ดคะแนน (แตะไปตั้งน้ำหนัก) · SOP · ลิงก์ระเบียบการ · โน้ต
//

import SwiftUI
import SwiftData

struct TCASEntryDetailView: View {
    @Bindable var entry: TCASEntry
    @Query private var records: [TCASScoreRecord]
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TCASWeightSetupView(entry: entry)
                } label: {
                    TCASScoreCard(entry: entry, records: records)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("คะแนนเป้าหมาย") {
                HStack {
                    TextField("0 = ไม่ระบุเป้า", value: $entry.targetScore, format: .number)
                        .keyboardType(.decimalPad)
                    Text("/ 100").foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Section {
                NavigationLink {
                    SOPEditorView(entry: entry)
                } label: {
                    HStack {
                        Label("SOP", systemImage: "doc.text")
                        Spacer()
                        Text(sopStatusText)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Section("ระเบียบการ") {
                TextField("วางลิงก์ระเบียบการจาก mytcas ที่นี่ (ถ้ามี)", text: $entry.admissionURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    openMyTCAS()
                } label: {
                    Label("เปิดดูเกณฑ์ใน mytcas", systemImage: "safari")
                }
            }

            Section("โน้ต") {
                TextEditor(text: $entry.notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle(entry.facultyName)
        .navigationBarTitleDisplayMode(.inline)
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
