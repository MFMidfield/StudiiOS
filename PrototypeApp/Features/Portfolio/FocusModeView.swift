//
//  FocusModeView.swift
//  Focus Mode: Pomodoro timer, Focus Timer, Reading Statistics.
//

import SwiftUI
import SwiftData

struct FocusModeView: View {
    @Environment(\.modelContext) private var context
    @Query private var sessions: [FocusSession]

    @State private var secondsRemaining = 25 * 60
    @State private var isRunning = false
    @State private var totalDuration = 25 * 60
    @State private var timer: Timer?

    private let presets: [(String, Int)] = [("โฟกัส 25 นาที", 25 * 60), ("โฟกัส 50 นาที", 50 * 60), ("พัก 5 นาที", 5 * 60)]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CardContainer {
                    Text("Pomodoro / Focus Timer")
                        .font(.subheadline).fontWeight(.semibold)
                    VStack(spacing: 16) {
                        Text(timeString)
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)

                        HStack(spacing: 12) {
                            ForEach(presets, id: \.0) { preset in
                                Button(preset.0) { setPreset(seconds: preset.1) }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                            }
                        }

                        HStack(spacing: 20) {
                            Button(isRunning ? "หยุดชั่วคราว" : "เริ่ม") { toggleRunning() }
                                .buttonStyle(.borderedProminent)
                            Button("รีเซ็ต") { reset() }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                CardContainer {
                    Text("สถิติการอ่าน (Reading Statistics)")
                        .font(.subheadline).fontWeight(.semibold)
                    HStack(spacing: 16) {
                        StatBlock(value: "\(todaysMinutes)", label: "นาทีวันนี้")
                        StatBlock(value: "\(weekMinutes)", label: "นาทีสัปดาห์นี้")
                        StatBlock(value: "\(sessions.filter(\.completed).count)", label: "เซสชันสำเร็จ")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("โฟกัส")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { timer?.invalidate() }
    }

    private var timeString: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    private var todaysMinutes: Int {
        sessions.filter { Calendar.current.isDateInToday($0.startedAt) && $0.completed }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var weekMinutes: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return sessions.filter { $0.startedAt >= weekAgo && $0.completed }
            .reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private func setPreset(seconds: Int) {
        timer?.invalidate()
        isRunning = false
        totalDuration = seconds
        secondsRemaining = seconds
    }

    private func toggleRunning() {
        isRunning.toggle()
        if isRunning {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if secondsRemaining > 0 {
                    secondsRemaining -= 1
                } else {
                    completeSession()
                }
            }
        } else {
            timer?.invalidate()
        }
    }

    private func reset() {
        timer?.invalidate()
        isRunning = false
        secondsRemaining = totalDuration
    }

    private func completeSession() {
        timer?.invalidate()
        isRunning = false
        context.insert(FocusSession(startedAt: .now.addingTimeInterval(-Double(totalDuration)), durationSeconds: totalDuration, completed: true))
        secondsRemaining = totalDuration
    }
}

private struct StatBlock: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold).foregroundStyle(Theme.Colors.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { FocusModeView() }
        .modelContainer(for: FocusSession.self, inMemory: true)
}
