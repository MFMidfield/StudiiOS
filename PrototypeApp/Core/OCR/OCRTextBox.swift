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
    /// Vision's alternative readings of the same line, best-first.
    /// Always non-empty and `candidates[0] == text`. Useful because the best
    /// candidate is often wrong in a way a later one isn't — see
    /// `SubjectCodeValidator` for why confidence can't be used to choose.
    let candidates: [String]

    /// `candidates` defaults to `[text]` so call sites that only asked Vision
    /// for the top candidate keep compiling unchanged.
    init(text: String, boundingBox: CGRect, confidence: Float, candidates: [String]? = nil) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
        let supplied = candidates ?? []
        self.candidates = supplied.isEmpty ? [text] : supplied
    }

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
