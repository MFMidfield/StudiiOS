//
//  PortfolioItemActions.swift
//  The single place that deletes a PortfolioItem. The row lives in SwiftData but
//  the image files live on disk under PortfolioImageStore — deleting the row
//  without its files leaks them permanently, because once the row is gone nothing
//  remembers the filenames. Both the detail screen and the grid context menu call
//  this; never write a second delete path.
//

import Foundation
import SwiftData

enum PortfolioItemActions {
    static func delete(_ item: PortfolioItem, in context: ModelContext) {
        for image in item.images {
            PortfolioImageStore.delete(image.filename)
        }
        context.delete(item)
        try? context.save()
    }
}
