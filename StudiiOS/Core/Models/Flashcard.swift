//
//  Flashcard.swift
//

import Foundation
import SwiftData

@Model
final class Flashcard {
    var front: String
    var back: String
    var createdAt: Date
    var lastReviewedAt: Date?
    var reviewCount: Int

    init(
        front: String,
        back: String,
        createdAt: Date = .now,
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.front = front
        self.back = back
        self.createdAt = createdAt
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
    }
}
