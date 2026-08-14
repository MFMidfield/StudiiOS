//
//  SetupSummaryView.swift
//  Setup wizard, phase 4 of 4: recap everything entered in phases 1-3
//  before handing off to the main app. Shown once — gated by
//  AppStorage("hasCompletedSetupSummary") in RootContainerView.
//

import SwiftUI
import SwiftData
import UIKit

struct SetupSummaryView: View {
    @AppStorage("hasCompletedSetupSummary") private var hasCompletedSetupSummary = false

    @Query private var allScheduleEntries: [ScheduleEntry]
    @Query private var semesterRecords: [SemesterRecord]

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    private var scheduleEntries: [ScheduleEntry] { allScheduleEntries.inTerm(activeTerm) }

    private let profile = StudentProfileStore.shared

    private var scheduleSubjectCount: Int {
        Set(scheduleEntries.map { $0.subjectName }.filter { !$0.isEmpty }).count
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("ตรวจสอบข้อมูล")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("ขั้นตอน 4")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    CardContainer {
                        HStack(spacing: 16) {
                            profileImageView
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(profile.firstName) \(profile.lastName)")
                                    .font(.headline)
                                if !profile.nickname.isEmpty {
                                    Text("ชื่อเล่น: \(profile.nickname)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        summaryRow(
                            icon: "calendar",
                            title: "ตารางเรียน",
                            detail: scheduleEntries.isEmpty
                                ? "ยังไม่ได้เพิ่ม"
                                : "\(scheduleEntries.count) คาบ ใน \(scheduleSubjectCount) วิชา"
                        )
                        summaryRow(
                            icon: "doc.text.fill",
                            title: "ใบ ปพ.",
                            detail: semesterRecords.isEmpty
                                ? "ยังไม่ได้เพิ่ม"
                                : "\(semesterRecords.count) รายวิชา"
                        )
                    }
                    .padding(.horizontal, 24)

                    Text("แก้ไขข้อมูลเหล่านี้ภายหลังได้ทุกเมื่อจากหน้าเกรด & GPA")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Button {
                hasCompletedSetupSummary = true
            } label: {
                Text("เริ่มต้นใช้งาน")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.primary)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.Colors.background)
    }

    @ViewBuilder
    private var profileImageView: some View {
        Group {
            if let image = profile.loadProfileImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Theme.Colors.primary.opacity(0.12))
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.primaryDeep)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private func summaryRow(icon: String, title: String, detail: String) -> some View {
        CardContainer {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.Colors.primaryDeep)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SetupSummaryView()
        .modelContainer(for: [ScheduleEntry.self, SemesterRecord.self, Term.self, TermSubject.self], inMemory: true)
}
