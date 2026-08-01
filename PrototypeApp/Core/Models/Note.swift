//
//  Note.swift
//

import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        content: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
