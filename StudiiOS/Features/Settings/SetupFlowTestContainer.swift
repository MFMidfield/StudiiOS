//
//  SetupFlowTestContainer.swift
//  Debug-only: replays the Setup wizard for testing.
//
//  The whole file sits inside #if DEBUG — there is no path to it in a release
//  build, and SettingsView only references it from its own debug section.
//
//  Split out of SettingsView.swift (588 lines, 4 structs).
//

import SwiftUI

#if DEBUG

/// Debug-only: replays the Setup wizard for testing. Mirrors the phase
/// switching in `RootContainerView`, plus a floating close button so
/// testers can bail out of any phase without finishing it.
struct SetupFlowTestContainer: View {
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    @AppStorage("hasCompletedScheduleSetup") private var hasCompletedScheduleSetup = false
    @AppStorage("hasCompletedGradeSetup") private var hasCompletedGradeSetup = false
    @AppStorage("hasCompletedSetupSummary") private var hasCompletedSetupSummary = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !hasCompletedProfileSetup {
                ProfileSetupView()
            } else if !hasCompletedScheduleSetup {
                NavigationStack { ScheduleSetupView() }
            } else if !hasCompletedGradeSetup {
                NavigationStack { GradeReportSetupView() }
            } else if !hasCompletedSetupSummary {
                SetupSummaryView()
            } else {
                VStack(spacing: 16) {
                    Text("จบขั้นตอน Setup แล้ว (โหมดทดสอบ)")
                    Button("ปิด") { dismiss() }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
}

#endif
