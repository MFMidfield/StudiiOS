//
//  OCRTextBox.swift
//  Shared value type for one line of text recognized by Vision, used by
//  both OCR parsers and by the debug viewer. Vision's coordinate space has
//  its origin at the BOTTOM-left with y increasing upward — the opposite of
//  SwiftUI — so anything drawing these boxes must flip y.
//

import CoreGraphics
import Foundation

struct OCRTextBox: Identifiable {
    let id = UUID()
    let text: String
    /// Normalized 0–1, origin bottom-left (Vision convention).
    let boundingBox: CGRect
    let confidence: Float

    var midX: CGFloat { boundingBox.midX }
    var midY: CGFloat { boundingBox.midY }

    /// One line for the console dump / copy-to-clipboard report.
    func debugLine(index: Int) -> String {
        String(
            format: "#%02d  \"%@\"  x %.3f–%.3f  y %.3f  conf %.2f",
            index,
            text,
            Double(boundingBox.minX),
            Double(boundingBox.maxX),
            Double(boundingBox.midY),
            Double(confidence)
        )
    }
}

/// Prints every box Vision returned to the Xcode console. Shared by both
/// parsers so the two dumps have an identical format. DEBUG builds only.
func dumpOCRBoxes(_ boxes: [OCRTextBox], label: String) {
    #if DEBUG
    AppLog.action("OCR", "===== \(label) · Vision คืน \(boxes.count) กล่อง =====")
    for (index, box) in boxes.enumerated() {
        AppLog.action("OCR", box.debugLine(index: index))
    }
    AppLog.action("OCR", "===== จบ =====")
    #endif
}
