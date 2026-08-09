//
//  PortfolioCard.swift
//  2-column grid cell for PortfolioView: cover image + title + date range +
//  category pill. Built manually (not CardContainer) so the cover image can
//  bleed edge-to-edge to the card's top corners.
//

import SwiftUI
import UIKit

struct PortfolioCard: View {
    let item: PortfolioItem

    @State private var coverThumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverView
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                Text(item.dateRangeText)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                categoryPill
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .task(id: item.coverImage?.filename) {
            guard let filename = item.coverImage?.filename else {
                coverThumbnail = nil
                return
            }
            coverThumbnail = PortfolioImageStore.loadThumbnail(filename)
        }
    }

    @ViewBuilder
    private var coverView: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(Theme.Colors.background)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay {
                    if let coverThumbnail {
                        Image(uiImage: coverThumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .clipped()

            if item.images.count > 1 {
                imageCountBadge
            }
        }
    }

    private var imageCountBadge: some View {
        Label("\(item.images.count)", systemImage: "photo.on.rectangle")
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.5))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(Theme.Spacing.xs)
    }

    private var categoryPill: some View {
        Text(item.category.label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(item.category.color.opacity(0.15))
            .foregroundStyle(item.category.color)
            .clipShape(Capsule())
    }
}
