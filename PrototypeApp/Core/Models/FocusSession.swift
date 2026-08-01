//
//  FocusSession.swift
//  Records completed Pomodoro/focus timer sessions for Reading Statistics.
//

import Foundation
import SwiftData

@Model
final class FocusSession {
    var startedAt: Date
    var durationSeconds: Int
    var completed: Bool

    init(
        startedAt: Date = .now,
        durationSeconds: Int,
        completed: Bool = true
    ) {
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.completed = completed
    }
}
