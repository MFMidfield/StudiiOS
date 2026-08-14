//
//  ScheduleOCRParser.swift
//  Best-effort, fully on-device parser that turns a photo of a school
//  timetable into draft ScheduleEntry rows: Vision reads the text,
//  TableGridBuilder recovers the table geometry, and this file decides what
//  each cell means. Results are always a *draft* meant to be reviewed in
//  ScheduleSetupView — cells the parser cannot prove are marked `needsReview`
//  rather than silently guessed.
//

import UIKit
import Vision

struct ScheduleDraftEntry: Identifiable {
    let id = UUID()
    var dayOfWeek: Int
    var startMinute: Int
    var endMinute: Int
    var subjectName: String
    /// The period number printed on the paper. Falls back to column index + 1
    /// when the header row was unreadable — never a bare 0-based index.
    var periodNumber: Int = 0
    /// True when the period's time was inferred from its neighbours rather than
    /// read off the sheet. Kept apart from `needsReview`, which folds this in.
    var timeIsGuessed: Bool = false
    var teacherName: String?
    var room: String?
    /// True when the parser could not prove its reading — the cell is a guess
    /// and the user has to confirm it.
    var needsReview: Bool = false
    /// Every plausible reading when the ambiguity is enumerable (e.g. a
    /// leading "0" that is either ง or อ). Empty means "no idea, just check".
    var reviewOptions: [String] = []
}

/// Outcome of one parse. Entries can be non-empty *and* carry a problem: a
/// missing time row is worth telling the user about, not worth throwing the
/// whole table away for.
struct ScheduleOCRResult {
    var entries: [ScheduleDraftEntry] = []
    var problem: Problem?

    enum Problem {
        case noTextFound
        case gridNotRecognized
        case timesNotRecognized

        var message: String {
            switch self {
            case .noTextFound:
                return "อ่านตัวหนังสือในรูปไม่ออกเลย ลองถ่ายใหม่ให้ชัดขึ้นและอย่าให้เอียง"
            case .gridNotRecognized:
                return "หาโครงตารางไม่เจอ ลองถ่ายให้เห็นตารางทั้งใบ ไม่มีมือหรือเงาบัง"
            case .timesNotRecognized:
                return "อ่านแถวเวลาไม่ออก เวลาที่ใส่ให้เป็นการเดา กรุณาตรวจก่อนบันทึก"
            }
        }
    }
}

enum ScheduleOCRParser {
    /// A/B knob for PLAN_OCRFix C5. Vision's language model is tuned for prose
    /// and can "correct" a subject code into a real word; on a sheet that is
    /// mostly codes and proper nouns it may do more harm than good. Flip this,
    /// re-run the same photo through the debug viewer, and compare the
    /// "ถูกเลย / ซ่อมได้ / ต้องให้คนดู" line before deciding.
    static var usesLanguageCorrection = true

    /// Runs Vision OCR on `image` off the main thread and calls `completion`
    /// with draft schedule rows on the main thread.
    static func parseSchedule(from image: UIImage, completion: @escaping ([ScheduleDraftEntry]) -> Void) {
        parseScheduleDetailed(from: image, onRawBoxes: nil) { completion($0.entries) }
    }

    /// Same as above, plus `onRawBoxes` — every line Vision recognized, before
    /// any heuristic runs, delivered on the main thread for OCRDebugView.
    ///
    /// Kept as a separate overload rather than a defaulted parameter so the
    /// existing `parseSchedule(from:) { ... }` trailing-closure call sites keep
    /// binding to `completion` under Swift's forward-scan matching.
    static func parseSchedule(
        from image: UIImage,
        onRawBoxes: (([OCRTextBox]) -> Void)?,
        completion: @escaping ([ScheduleDraftEntry]) -> Void
    ) {
        parseScheduleDetailed(from: image, onRawBoxes: onRawBoxes) { completion($0.entries) }
    }

    /// The full result, including *why* a parse came back thin. Callers that
    /// only need the rows should use `parseSchedule` above.
    static func parseScheduleDetailed(
        from image: UIImage,
        onRawBoxes: (([OCRTextBox]) -> Void)?,
        completion: @escaping (ScheduleOCRResult) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async {
                onRawBoxes?([])
                completion(ScheduleOCRResult(entries: [], problem: .noTextFound))
            }
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let boxes = observations.compactMap { observation -> OCRTextBox? in
                let candidates = observation.topCandidates(10)
                guard let best = candidates.first else { return nil }
                return OCRTextBox(
                    text: best.string,
                    boundingBox: observation.boundingBox,
                    confidence: best.confidence,
                    candidates: candidates.map(\.string)
                )
            }
            dumpOCRBoxes(boxes, label: "Schedule")
            let result = buildDraftSchedule(from: boxes)
            DispatchQueue.main.async {
                onRawBoxes?(boxes)
                completion(result)
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = usesLanguageCorrection
        request.recognitionLanguages = ["th-TH", "en-US"]

        let orientation = cgOrientation(from: image.imageOrientation)
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try? handler.perform([request])
        }
    }

    // MARK: - Subject code resolution

    /// What a single text box turned out to be, code-wise.
    enum SubjectCodeOutcome {
        /// The box is not a subject-code slot at all (teacher name, room, …).
        case notACode
        /// Vision's best reading was already a well-formed code.
        case alreadyValid(String)
        /// Fixed with certainty — either an alternative candidate parsed
        /// cleanly, or the confusion table had exactly one option.
        case repaired(String)
        /// Cannot be decided here. `options` may be empty (no idea at all)
        /// or hold every plausible reading for the user to pick from.
        case needsReview(best: String, options: [String])
    }

    /// Pipeline, in order — do not reorder:
    ///   1. any candidate that already parses as a valid code wins
    ///   2. single-option confusion repair on the best candidate
    ///   3. give up → flag the cell for review
    /// Confidence is deliberately never consulted (see SubjectCodeValidator).
    static func classifySubjectCode(_ box: OCRTextBox) -> SubjectCodeOutcome {
        if let valid = box.candidates.first(where: SubjectCodeValidator.isValid) {
            let trimmed = valid.trimmingCharacters(in: .whitespacesAndNewlines)
            return valid == box.candidates.first ? .alreadyValid(trimmed) : .repaired(trimmed)
        }
        // Only treat this box as a code slot if *some* reading has the shape
        // of one; otherwise plain text would come back as "unrepairable code".
        // The loose test is deliberate: a code Vision read one character short
        // must still land here so it gets flagged, instead of sailing through
        // as a subject named "32101".
        guard box.candidates.contains(where: SubjectCodeValidator.looksLikeCodeSlot) else { return .notACode }

        switch SubjectCodeValidator.repair(box.text) {
        case .alreadyValid(let code):
            return .alreadyValid(code)
        case .repaired(let code):
            return .repaired(code)
        case .ambiguous(let options):
            return .needsReview(best: options.first ?? box.text, options: options)
        case .unknown:
            return .needsReview(best: box.text.trimmingCharacters(in: .whitespacesAndNewlines), options: [])
        }
    }

    // MARK: - Grid → drafts

    /// What one cell of the table turned out to contain.
    private struct CellContent {
        var name = ""
        var teacher: String?
        var room: String?
        /// Doubt about the subject code specifically — this is what the
        /// cross-image vote can clear.
        var codeNeedsReview = false
        /// Doubt about some other field ("ครูA"). The vote must NOT clear this:
        /// agreeing on the code says nothing about the teacher's name.
        var fieldNeedsReview = false
        var options: [String] = []
        /// True when `name` came out of the subject-code path — only those
        /// cells take part in the cross-image vote.
        var isCode = false
        /// True when `name` was already a well-formed code with no repair at
        /// all. These are never overwritten by the vote.
        var isProvenCode = false
        /// True when `name` was reached without the parser having to pick
        /// between readings — either already valid, or repaired with exactly
        /// one option available. Only these are evidence for the other cells.
        var isUnambiguousCode = false

        var needsReview: Bool { codeNeedsReview || fieldNeedsReview }
    }

    private struct CellReading {
        let day: Int
        let period: Int
        var content: CellContent
    }

    /// Recovers the table geometry, reads every non-empty cell, then lets the
    /// cells correct each other before anything is emitted. Page titles and
    /// signature lines fall outside the fitted grid and are dropped without a
    /// special case.
    private static func buildDraftSchedule(from boxes: [OCRTextBox]) -> ScheduleOCRResult {
        guard !boxes.isEmpty else {
            return ScheduleOCRResult(entries: [], problem: .noTextFound)
        }
        guard let grid = TableGridBuilder.build(from: boxes) else {
            return ScheduleOCRResult(entries: [], problem: .gridNotRecognized)
        }

        var readings: [CellReading] = []
        for day in 0..<grid.dayCount {
            for period in 0..<grid.periodCount {
                let fragments = grid.cells[day][period]
                guard !fragments.isEmpty else { continue }
                let content = readCell(fragments)
                guard !content.name.isEmpty else { continue }
                readings.append(CellReading(day: day, period: period, content: content))
            }
        }

        // Order matters: teacher spellings have to be merged first, because
        // the vote leans on "one teacher teaches one subject" and two
        // spellings of one teacher would quietly break that.
        unifyTeacherNames(&readings)
        let voted = applyCrossImageVote(&readings)

        var entries: [ScheduleDraftEntry] = []
        var sawMeasuredTime = false
        for reading in readings {
            let time = grid.periodTimes[reading.period]
            if time?.isInferred == false { sawMeasuredTime = true }
            let fallbackStart = 8 * 60 + 30 + reading.period * 50
            let start = time?.start ?? fallbackStart
            let end = time.map { max($0.end, $0.start + 5) } ?? (fallbackStart + 50)

            entries.append(
                ScheduleDraftEntry(
                    dayOfWeek: grid.dayNumbers[reading.day],
                    startMinute: start,
                    endMinute: end,
                    subjectName: reading.content.name,
                    periodNumber: grid.printedPeriodNumbers[reading.period] ?? (reading.period + 1),
                    timeIsGuessed: time?.isInferred != false,
                    teacherName: reading.content.teacher,
                    room: reading.content.room,
                    needsReview: reading.content.needsReview || time?.isInferred != false,
                    reviewOptions: reading.content.options
                )
            )
        }

        entries.sort {
            $0.dayOfWeek != $1.dayOfWeek ? $0.dayOfWeek < $1.dayOfWeek : $0.startMinute < $1.startMinute
        }

        #if DEBUG
        let flagged = entries.filter(\.needsReview).count
        AppLog.action(
            "OCR",
            "กริด \(grid.dayCount)×\(grid.periodCount) · วันเป็น\(grid.daysAreRows ? "แถว" : "คอลัมน์")"
                + " · ได้ \(entries.count) รายการ · โหวตซ่อม \(voted) · ติดธง \(flagged)"
        )
        #endif

        // A grid that produced no cells at all was not really a grid.
        if entries.isEmpty {
            return ScheduleOCRResult(entries: [], problem: .gridNotRecognized)
        }
        return ScheduleOCRResult(entries: entries, problem: sawMeasuredTime ? nil : .timesNotRecognized)
    }

    /// Splits the lines of one cell into subject code / teacher / room, then
    /// falls back to free text so activity cells ("โฮมรูม", "พัก", "ชุมนุม",
    /// "กิจกรรมในเครื่องแบบ") survive instead of being dropped. A timetable
    /// with holes in it is worse than one with a few rough labels.
    private static func readCell(_ fragments: [OCRCellFragment]) -> CellContent {
        var content = CellContent()
        var code: (text: String, needsReview: Bool, options: [String], proven: Bool, unambiguous: Bool)?
        var freeText: [String] = []

        for fragment in fragments {
            let text = fragment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            if code == nil {
                switch classifySubjectCode(fragment.asTextBox) {
                case .alreadyValid(let value):
                    code = (value, false, [], true, true)
                    continue
                case .repaired(let value):
                    code = (value, false, [], false, true)
                    continue
                case .needsReview(let best, let options):
                    code = (best, true, options, false, false)
                    continue
                case .notACode:
                    break
                }
            }
            if content.teacher == nil, let reading = CellFieldValidator.teacher(in: text) {
                content.teacher = reading.name
                if reading.needsReview { content.fieldNeedsReview = true }
                continue
            }
            if content.room == nil, CellFieldValidator.isRoom(text) {
                content.room = text
                continue
            }
            freeText.append(text)
        }

        if let code {
            content.name = code.text
            content.isCode = true
            content.isProvenCode = code.proven
            content.isUnambiguousCode = code.unambiguous
            content.codeNeedsReview = code.needsReview
            content.options = code.options
            return content
        }
        let activity = freeText.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !activity.isEmpty {
            content.name = activity
            return content
        }
        // Teacher or room only: something was read but the subject itself was
        // not — keep the cell so the user sees there is something to fill in.
        if let teacher = content.teacher {
            content.name = teacher
            content.fieldNeedsReview = true
            return content
        }
        if let room = content.room {
            content.name = room
            content.fieldNeedsReview = true
        }
        return content
    }

    // MARK: - Cross-cell correction

    /// Collapses the spellings of one teacher onto a single canonical name.
    private static func unifyTeacherNames(_ readings: inout [CellReading]) {
        let mapping = CellFieldValidator.canonicalTeacherNames(readings.compactMap(\.content.teacher))
        for index in readings.indices {
            guard let teacher = readings[index].content.teacher else { continue }
            readings[index].content.teacher = mapping[teacher] ?? teacher
        }
    }

    /// Lets cells that read cleanly repair the ones that didn't, and returns
    /// how many were fixed.
    ///
    /// A unanimous ledger answer outranks a confusion-table repair on purpose:
    /// several readings from different places on the same sheet are stronger
    /// evidence than one guess about the shape of one character. It never
    /// touches a cell that was already well-formed on its own — see
    /// `SubjectCodeLedger` for why overriding those would do more harm than
    /// good on tails that several subjects share.
    private static func applyCrossImageVote(_ readings: inout [CellReading]) -> Int {
        let ledger = SubjectCodeLedger(
            observations: readings
                .filter(\.content.isUnambiguousCode)
                .map { (code: $0.content.name, teacher: $0.content.teacher) }
        )

        var fixed = 0
        for index in readings.indices {
            let content = readings[index].content
            guard content.isCode, !content.isProvenCode else { continue }
            guard let tail = SubjectCodeValidator.tail(of: content.name),
                  let lead = ledger.leadingConsonant(tail: tail, teacher: content.teacher)
            else { continue }

            let agreed = String(lead) + tail
            if agreed != content.name { fixed += 1 }
            readings[index].content.name = agreed
            readings[index].content.codeNeedsReview = false
            readings[index].content.options = []
        }
        return fixed
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
