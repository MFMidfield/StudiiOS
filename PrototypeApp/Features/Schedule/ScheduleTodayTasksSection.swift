//
//  ScheduleTodayTasksSection.swift
//  Card showing assignments due on the selected day's real calendar date
//  (see PeriodShiftCalculator.date(forDay:in:)), with a push to the
//  existing AssignmentListView for the full list.
//

import SwiftUI
import SwiftData

struct ScheduleTodayTasksSection: View {
    let selectedDay: Int
    let targetDate: Date

    @Query private var allAssignments: [Assignment]
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]

    private var tasks: [Assignment] {
        allAssignments.filter {
            guard !$0.isDone, let due = $0.resolvedDueDate else { return false }
            return Calendar.current.isDate(due, inSameDayAs: targetDate)
        }
    }

    var body: some View {
        CardContainer {
            header
            if tasks.isEmpty {
                emptyState
            } else {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("งาน / การบ้านวันนี้")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Theme.Colors.textPrimary)

            if !tasks.isEmpty {
                Text("\(tasks.count) รายการ")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.primary.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer()

            NavigationLink {
                AssignmentListView()
            } label: {
                HStack(spacing: 2) {
                    Text("ดูทั้งหมด")
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var emptyState: some View {
        Text("ไม่มีงานส่งวัน\(ScheduleConstants.dayLabels[selectedDay] ?? "") 🎉")
            .font(.subheadline)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
    }

    private func taskRow(_ task: Assignment) -> some View {
        Button {
            AppLog.action("Schedule", "แตะงาน: \(task.title)")
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(subjectColor(for: task).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: subjectIcon(for: task))
                        .foregroundStyle(subjectColor(for: task))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(task.subjectName.isEmpty ? "ไม่ระบุวิชา" : task.subjectName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(task.resolvedDueDate.map { "ส่ง \($0.thaiShortNoYearString)" } ?? "ไม่กำหนดส่ง")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Text(task.title)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func matchingSubject(for task: Assignment) -> Subject? {
        guard !task.subjectName.isEmpty else { return nil }
        return subjects.first { $0.name.caseInsensitiveCompare(task.subjectName) == .orderedSame }
    }

    private func subjectColor(for task: Assignment) -> Color {
        matchingSubject(for: task)?.color ?? Theme.Colors.textSecondary
    }

    private func subjectIcon(for task: Assignment) -> String {
        matchingSubject(for: task)?.iconName ?? "doc.text.fill"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Subject.self, Assignment.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )
    let math = Subject(name: "คณิตศาสตร์เพิ่มเติม ม.5", colorHex: "4A7DFF", iconName: "function")
    container.mainContext.insert(math)

    let today = Date.now
    let a1 = Assignment(title: "แบบฝึกหัด 2.1 ข้อ 1-20", dueDate: today, subjectName: math.name)
    let a2 = Assignment(title: "อ่านบทที่ 3 และทำแบบฝึกหัดท้ายบท", dueDate: today, subjectName: "ฟิสิกส์")
    [a1, a2].forEach { container.mainContext.insert($0) }

    return ScrollView {
        ScheduleTodayTasksSection(selectedDay: 1, targetDate: today)
            .padding()
    }
    .background(Theme.Colors.background)
    .modelContainer(container)
}
