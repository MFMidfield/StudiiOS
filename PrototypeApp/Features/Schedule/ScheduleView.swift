//
//  ScheduleView.swift
//  ตารางเรียน — cleared, left as a blank page.
//

import SwiftUI

struct ScheduleView: View {
    var body: some View {
        VStack {
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background)
        .navigationTitle("ตารางเรียน")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ScheduleView() }
}
