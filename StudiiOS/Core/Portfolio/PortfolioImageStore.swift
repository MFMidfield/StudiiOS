//
//  PortfolioImageStore.swift
//  File-system storage for portfolio images. SwiftData only holds the
//  filename (PortfolioImage); bytes live in Documents/PortfolioImages.
//

import UIKit
import ImageIO

enum PortfolioImageStore {
    private static let cache = NSCache<NSString, UIImage>()

    static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PortfolioImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    enum StoreError: Error {
        case encodingFailed
        case writeFailed
    }

    /// Downscales so the longer side is at most 2000px, compresses to JPEG 0.85,
    /// writes to disk, and returns the generated filename.
    static func save(_ image: UIImage) throws -> String {
        let maxSide: CGFloat = 2000
        let longerSide = max(image.size.width, image.size.height)
        let resized: UIImage
        if longerSide > maxSide {
            let scale = maxSide / longerSide
            let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        } else {
            resized = image
        }

        guard let data = resized.jpegData(compressionQuality: 0.85) else {
            throw StoreError.encodingFailed
        }

        let filename = "portfolio_\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw StoreError.writeFailed
        }
        return filename
    }

    /// Loads the full-size image. Returns nil if the file is missing.
    static func load(_ filename: String) -> UIImage? {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Loads a small decoded-at-size version for grid cells, backed by an
    /// in-memory cache. Never decodes the full image — the grid would stutter.
    static func loadThumbnail(_ filename: String, maxPixel: CGFloat = 400) -> UIImage? {
        let key = filename as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let url = directory.appendingPathComponent(filename)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let thumbnail = UIImage(cgImage: cgThumb)
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    static func delete(_ filename: String) {
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }

    /// Used by SettingsView.resetAllData() to wipe every stored image file.
    static func deleteAll() {
        cache.removeAllObjects()
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
