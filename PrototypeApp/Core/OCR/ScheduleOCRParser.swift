//
//  ScheduleOCRParser.swift
//  Best-effort, fully on-device parser that turns a photo of a school
//  timetable into draft ScheduleEntry rows: Vision reads the text, then a
//  heuristic maps each text box onto a (day column, time row) grid using
//  its position in the image. Results are always a *draft* meant to be
//  reviewed/edited in ScheduleSetupView — table layouts vary too much
//  across schools for this to be reliable without user confirmation.
//

import UIKit
import Vision

struct ScheduleDraftEntry: Identifiable {
    let id = UUID()
    var dayOfWeek: Int
    var startTime: Date
    var endTime: Date
    var subjectName: String
}

private struct RecognizedTextBox {
    let text: String
    let boundingBox: CGRect
}

enum ScheduleOCRParser {
    private static let dayKeywords: [(pattern: String, day: Int)] = [
        ("จันทร์", 1), ("อังคาร", 2), ("พุธ", 3), ("พฤหัส", 4), ("ศุกร์", 5), ("เสาร์", 6), ("อาทิตย์", 7),
        ("MON", 1), ("TUE", 2), ("WED", 3), ("THU", 4), ("FRI", 5), ("SAT", 6), ("SUN", 7),
    ]

    private static let timeRegex = try! NSRegularExpression(pattern: "([01]?\\d|2[0-3])[:.]([0-5]\\d)")

    /// Runs Vision OCR on `image` off the main thread and calls `completion` with
    /// draft schedule rows on the main thread. Returns an empty array if no day
    /// header or no time labels could be found (table layout not recognized).
    static func parseSchedule(from image: UIImage, completion: @escaping ([ScheduleDraftEntry]) -> Void) {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async { completion([]) }
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let boxes = observations.compactMap { observation -> RecognizedTextBox? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return RecognizedTextBox(text: candidate.string, boundingBox: observation.boundingBox)
            }
            let drafts = buildDraftSchedule(from: boxes)
            DispatchQueue.main.async { completion(drafts) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["th-TH", "en-US"]

        let orientation = cgOrientation(from: image.imageOrientation)
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try? handler.perform([request])
        }
    }

    /// Maps recognized text boxes onto a day/time grid:
    /// 1. Boxes matching a day name become column anchors (x position).
    /// 2. Boxes matching a time like "08:30" become row anchors (y position),
    ///    sorted top-to-bottom (Vision's boundingBox origin is bottom-left).
    /// 3. Every remaining box is assigned to its nearest column and the row
    ///    band it falls into, becoming that cell's subject name.
    private static func buildDraftSchedule(from boxes: [RecognizedTextBox]) -> [ScheduleDraftEntry] {
        var dayColumns: [(day: Int, x: CGFloat)] = []
        for box in boxes {
            for (pattern, day) in dayKeywords where box.text.localizedCaseInsensitiveContains(pattern) {
                dayColumns.append((day, box.boundingBox.midX))
                break
            }
        }
        guard !dayColumns.isEmpty else { return [] }

        struct TimeRow { let y: CGFloat; let hour: Int; let minute: Int }
        var timeRows: [TimeRow] = []
        for box in boxes {
            let ns = box.text as NSString
            if let match = timeRegex.firstMatch(in: box.text, range: NSRange(location: 0, length: ns.length)) {
                let hour = Int(ns.substring(with: match.range(at: 1))) ?? 0
                let minute = Int(ns.substring(with: match.range(at: 2))) ?? 0
                timeRows.append(TimeRow(y: box.boundingBox.midY, hour: hour, minute: minute))
            }
        }
        timeRows.sort { $0.y > $1.y }
        guard timeRows.count >= 2 else { return [] }

        let calendar = Calendar.current
        let today = Date()

        func time(hour: Int, minute: Int) -> Date {
            var components = calendar.dateComponents([.year, .month, .day], from: today)
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components) ?? today
        }

        var drafts: [ScheduleDraftEntry] = []
        for box in boxes {
            let text = box.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if dayKeywords.contains(where: { text.localizedCaseInsensitiveContains($0.pattern) }) { continue }
            let ns = text as NSString
            if timeRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil { continue }

            guard let nearestDay = dayColumns.min(by: { abs($0.x - box.boundingBox.midX) < abs($1.x - box.boundingBox.midX) }) else { continue }
            guard let rowIndex = timeRows.firstIndex(where: { box.boundingBox.midY >= $0.y }) else { continue }

            let startRow = timeRows[rowIndex]
            let endRow = rowIndex > 0 ? timeRows[rowIndex - 1] : nil
            let startTime = time(hour: startRow.hour, minute: startRow.minute)
            let endTime = endRow.map { time(hour: $0.hour, minute: $0.minute) } ?? startTime.addingTimeInterval(50 * 60)

            drafts.append(ScheduleDraftEntry(dayOfWeek: nearestDay.day, startTime: startTime, endTime: endTime, subjectName: text))
        }

        return drafts.sorted {
            $0.dayOfWeek != $1.dayOfWeek ? $0.dayOfWeek < $1.dayOfWeek : $0.startTime < $1.startTime
        }
    }

    private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
