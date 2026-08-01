//
//  GradeReportOCRParser.swift
//  Best-effort, fully on-device parser that turns a photo of a Thai
//  report card (ปพ.) into draft SemesterRecord rows: Vision reads the
//  text, then a heuristic maps each row's subject name / หน่วยกิต /
//  เกรด onto columns using their position in the image. Results are
//  always a *draft* meant to be reviewed/edited in GradeReportSetupView.
//

import UIKit
import Vision

struct GradeDraftEntry: Identifiable {
    let id = UUID()
    var subjectName: String
    var creditHours: Double
    var gradePoint: Double
}

private struct RecognizedTextBox {
    let text: String
    let boundingBox: CGRect
}

enum GradeReportOCRParser {
    private static let numberRegex = try! NSRegularExpression(pattern: "^\\d+(\\.\\d+)?$")

    static func parseGradeReport(from image: UIImage, completion: @escaping ([GradeDraftEntry]) -> Void) {
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
            let drafts = buildDraftEntries(from: boxes)
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

    /// 1. Locate the "หน่วยกิต" / "เกรด" header cells to anchor two columns.
    /// 2. Cluster remaining boxes into table rows by y-proximity.
    /// 3. Within each row: numeric boxes go to whichever column they're
    ///    closest to (or left/right order if no header was found); the
    ///    rest of the text becomes the subject name.
    private static func buildDraftEntries(from boxes: [RecognizedTextBox]) -> [GradeDraftEntry] {
        var creditColumnX: CGFloat?
        var gradeColumnX: CGFloat?
        for box in boxes {
            if box.text.localizedCaseInsensitiveContains("หน่วยกิต") {
                creditColumnX = box.boundingBox.midX
            } else if box.text.localizedCaseInsensitiveContains("เกรด") {
                gradeColumnX = box.boundingBox.midX
            }
        }

        let bodyBoxes = boxes.filter {
            !$0.text.localizedCaseInsensitiveContains("หน่วยกิต")
                && !$0.text.localizedCaseInsensitiveContains("เกรด")
                && !$0.text.localizedCaseInsensitiveContains("รายวิชา")
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        guard !bodyBoxes.isEmpty else { return [] }

        var rows: [[RecognizedTextBox]] = []
        var currentRow: [RecognizedTextBox] = []
        var currentRowY: CGFloat?
        let rowThreshold: CGFloat = 0.025

        for box in bodyBoxes {
            if let refY = currentRowY, abs(box.boundingBox.midY - refY) > rowThreshold {
                rows.append(currentRow)
                currentRow = []
                currentRowY = nil
            }
            currentRow.append(box)
            currentRowY = currentRowY.map { min($0, box.boundingBox.midY) } ?? box.boundingBox.midY
        }
        if !currentRow.isEmpty { rows.append(currentRow) }

        var drafts: [GradeDraftEntry] = []
        for row in rows {
            let numeric = row.filter { isNumeric($0.text) }.sorted { $0.boundingBox.midX < $1.boundingBox.midX }
            let textParts = row.filter { !isNumeric($0.text) }
                .sorted { $0.boundingBox.midX < $1.boundingBox.midX }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            let subjectName = textParts.joined(separator: " ")
            guard !subjectName.isEmpty else { continue }

            var credit: Double?
            var grade: Double?
            if let creditX = creditColumnX, let gradeX = gradeColumnX {
                for box in numeric {
                    let value = Double(box.text) ?? 0
                    if abs(box.boundingBox.midX - creditX) < abs(box.boundingBox.midX - gradeX) {
                        credit = value
                    } else {
                        grade = value
                    }
                }
            } else if numeric.count >= 2 {
                credit = Double(numeric[0].text)
                grade = Double(numeric[1].text)
            }

            guard let creditHours = credit, let gradePoint = grade else { continue }
            drafts.append(GradeDraftEntry(subjectName: subjectName, creditHours: creditHours, gradePoint: gradePoint))
        }

        return drafts
    }

    private static func isNumeric(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = trimmed as NSString
        return numberRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) != nil
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
