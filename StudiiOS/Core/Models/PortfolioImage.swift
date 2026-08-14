//
//  PortfolioImage.swift
//  Metadata row for one portfolio image. Bytes live on disk
//  (see Core/Portfolio/PortfolioImageStore.swift) — only the filename is
//  stored here, matching the precedent in StudentProfileStore.
//

import Foundation
import SwiftData

@Model
final class PortfolioImage {
    var filename: String
    var sortOrder: Int
    var createdAt: Date
    var item: PortfolioItem?

    init(filename: String, sortOrder: Int, createdAt: Date = .now) {
        self.filename = filename
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
