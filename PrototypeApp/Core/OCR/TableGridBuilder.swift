//
//  TableGridBuilder.swift
//  Turns the flat list of lines Vision returns into an actual table: finds the
//  two axes of the grid, fits an evenly spaced line through each, and drops
//  every line into the cell it belongs to.
//
//  Two measurements on real timetable photos drive the whole design:
//
//  1. Vision gets *positions* essentially 100% right even when it gets
//     characters wrong. So geometry is the source of truth, never the text.
//  2. School timetables are printed on a near-perfect grid (row pitch was
//     0.084 and column pitch 0.0693, dead constant across the sheet). So a
//     fitted line `pos = origin + step·index` recovers rows and columns that
//     Vision could not read at all — the Wednesday row here came back purely
//     from the fit, because "พุธ" was never recognized.
//
//  That is also why day *names* are never used to define the layout: they are
//  exactly the thing that goes missing. The axis comes from whatever label
//  repeats once per row ("โฮมรูม", "พัก"); the names only label it afterwards.
//
//  Orientation is detected, never assumed — some schools print days across the
//  top instead of down the side.
//

import CoreGraphics
import Foundation

// MARK: - Model

/// One piece of text sitting in a single cell. Usually a whole line from
/// Vision; a line wide enough to straddle several columns is cut up first.
struct OCRCellFragment {
    let text: String
    let candidates: [String]
    /// Normalized centre in Vision space (origin bottom-left).
    let center: CGPoint
    let source: OCRTextBox

    /// The fragment as a box again, so the subject-code validator can inspect
    /// its candidates exactly as it would for an unsplit line.
    var asTextBox: OCRTextBox {
        OCRTextBox(
            text: text,
            boundingBox: source.boundingBox,
            confidence: source.confidence,
            candidates: candidates
        )
    }
}

struct OCRTableGrid {
    /// An evenly spaced axis fitted through anchor positions.
    struct Axis {
        /// Centre of index 0, already nudged onto the cell content.
        let origin: CGFloat
        /// Signed pitch per index. Negative when running top→bottom, because
        /// Vision's y grows upward.
        let step: CGFloat
        let count: Int
        /// True when the axis runs along y.
        let isVertical: Bool

        func position(_ index: Int) -> CGFloat { origin + step * CGFloat(index) }

        /// Index whose ±½-step band contains `position`, or nil when outside
        /// the table entirely — which is how page titles and signature lines
        /// get dropped without a special case.
        func index(for position: CGFloat) -> Int? {
            guard step != 0 else { return nil }
            let raw = (position - origin) / step
            let index = Int(raw.rounded())
            guard index >= 0, index < count else { return nil }
            return index
        }
    }

    struct PeriodTime {
        let start: Int
        let end: Int
        /// True when no time label was readable for this column and the value
        /// was filled in from its neighbours — always worth a review flag.
        let isInferred: Bool
    }

    let dayAxis: Axis
    let periodAxis: Axis
    /// False when the school prints days across the top instead.
    let daysAreRows: Bool
    /// dayAxis index → weekday 1…7 (1 = Monday). Rows whose name Vision could
    /// not read are filled in by counting from the ones it could.
    let dayNumbers: [Int]
    let periodTimes: [Int: PeriodTime]
    /// `cells[dayIndex][periodIndex]`, each cell's lines ordered top→bottom.
    let cells: [[[OCRCellFragment]]]

    var dayCount: Int { dayAxis.count }
    var periodCount: Int { periodAxis.count }
}

// MARK: - Builder

enum TableGridBuilder {

    // MARK: Tunables — all in normalized image units (0…1)

    /// Two anchors closer than this are the same row/column.
    private static let clusterTolerance: CGFloat = 0.012
    /// An anchor group must stay within this on the axis it does NOT span.
    private static let perpendicularTolerance: CGFloat = 0.05
    /// …and cover at least this much of the image on the axis it does span.
    private static let minimumSpan: CGFloat = 0.10
    /// A line wider than this many cells is assumed to straddle them.
    private static let straddleFactor: CGFloat = 1.5
    /// Residual allowed when checking an anchor group really is evenly spaced.
    private static let fitTolerance: CGFloat = 0.3
    /// Sanity bounds — anything outside means the fit found noise, not a table.
    private static let dayCountRange = 2...10
    private static let periodCountRange = 2...20

    // MARK: Day names

    static let dayKeywords: [(pattern: String, day: Int)] = [
        ("จันทร์", 1), ("อังคาร", 2), ("พุธ", 3), ("พฤหัส", 4), ("ศุกร์", 5), ("เสาร์", 6), ("อาทิตย์", 7),
        ("MON", 1), ("TUE", 2), ("WED", 3), ("THU", 4), ("FRI", 5), ("SAT", 6), ("SUN", 7),
    ]

    /// Weekday a header refers to, or nil. Long lines are rejected so a teacher
    /// name that happens to contain a day word can't be mistaken for a header.
    static func dayNumber(in text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 12 else { return nil }
        for (pattern, day) in dayKeywords where trimmed.localizedCaseInsensitiveContains(pattern) {
            return day
        }
        return nil
    }

    // MARK: Times

    /// A printed period, e.g. "08.30-09.20". Both ends are required: a lone
    /// "00.00" from a stray line is not a period, which is what keeps the
    /// garbage "00.00-00.00" box out of the column anchors.
    private static let timeRangeRegex = try! NSRegularExpression(
        pattern: "([01]?\\d|2[0-3])[:.]([0-5]\\d)\\s*[-–—~]\\s*([01]?\\d|2[0-3])[:.]([0-5]\\d)"
    )

    struct TimeRange {
        let start: Int
        let end: Int
        /// Where in the source string this range sat, 0…1. Needed because one
        /// Vision line can hold the times of eight periods at once.
        let textFraction: CGFloat
    }

    /// Every plausible period in `text`, in reading order. Ranges that don't
    /// move forward in time, or that run shorter than 20 / longer than 180
    /// minutes, are rejected.
    static func timeRanges(in text: String) -> [TimeRange] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }
        let matches = timeRangeRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match -> TimeRange? in
            let start = (Int(ns.substring(with: match.range(at: 1))) ?? 0) * 60
                + (Int(ns.substring(with: match.range(at: 2))) ?? 0)
            let end = (Int(ns.substring(with: match.range(at: 3))) ?? 0) * 60
                + (Int(ns.substring(with: match.range(at: 4))) ?? 0)
            let length = end - start
            guard length >= 20, length <= 180 else { return nil }
            let middle = CGFloat(match.range.location) + CGFloat(match.range.length) / 2
            return TimeRange(start: start, end: end, textFraction: middle / CGFloat(ns.length))
        }
    }

    // MARK: Tokenizing

    /// Whitespace-separated tokens, each with the fraction of the string it
    /// sits at — that fraction is what maps a token back onto an x position
    /// when one Vision line spans several columns.
    private static func tokens(in text: String) -> [(text: String, fraction: CGFloat)] {
        let ns = text as NSString
        let length = CGFloat(ns.length)
        guard length > 0 else { return [] }
        var result: [(text: String, fraction: CGFloat)] = []
        var location = 0
        for piece in text.components(separatedBy: .whitespacesAndNewlines) {
            let pieceLength = (piece as NSString).length
            if !piece.isEmpty {
                result.append((piece, (CGFloat(location) + CGFloat(pieceLength) / 2) / length))
            }
            location += pieceLength + 1
        }
        return result
    }

    /// True when the line is nothing but small standalone integers — the
    /// "0 1 2 … 10" period header. Room numbers are three digits, so a room
    /// can never be mistaken for a header.
    static func isPeriodNumberOnly(_ text: String) -> Bool {
        let parts = tokens(in: text)
        guard !parts.isEmpty else { return false }
        return parts.allSatisfy { part in
            guard part.text.count <= 2, let value = Int(part.text) else { return false }
            return (0...12).contains(value)
        }
    }

    private static func periodNumberFractions(in text: String) -> [CGFloat] {
        tokens(in: text).compactMap { part -> CGFloat? in
            guard part.text.count <= 2, let value = Int(part.text), (0...12).contains(value) else { return nil }
            return part.fraction
        }
    }

    // MARK: - Entry point

    static func build(from boxes: [OCRTextBox]) -> OCRTableGrid? {
        let clean = boxes.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard clean.count >= 8 else { return nil }

        let dayBoxes = clean.filter { dayNumber(in: $0.text) != nil }
        let daysAreRows = detectDaysAreRows(clean, dayBoxes: dayBoxes)

        // Day axis: whatever label repeats once per day. Day names join the
        // contest but rarely win, because at least one of them is unreadable.
        var dayCandidates = repeatedTextCandidates(clean, vertical: daysAreRows)
        if dayBoxes.count >= 3 {
            dayCandidates.append(points(of: dayBoxes, vertical: daysAreRows))
        }
        guard let dayPositions = bestPositions(dayCandidates),
              let dayFit = fitAxis(positions: dayPositions, vertical: daysAreRows)
        else { return nil }

        // Period axis: the number header first, the time row as backup.
        var periodCandidates = [
            numericHeaderCandidate(clean, vertical: !daysAreRows),
            timeCandidate(clean, vertical: !daysAreRows),
        ]
        periodCandidates += repeatedTextCandidates(clean, vertical: !daysAreRows)
        guard let periodPositions = bestPositions(periodCandidates),
              let periodFit = fitAxis(positions: periodPositions, vertical: !daysAreRows)
        else { return nil }

        // A day header landing outside the fitted range means the anchor label
        // was missing on that row — widen rather than lose the whole day.
        var headerIndices: [Int] = []
        for box in dayBoxes {
            let raw = ((daysAreRows ? box.midY : box.midX) - dayFit.origin) / dayFit.step
            let index = Int(raw.rounded())
            guard abs(raw - CGFloat(index)) <= 0.5, index >= -3, index <= dayFit.count + 2 else { continue }
            headerIndices.append(index)
        }
        let lowestDay = min(0, headerIndices.min() ?? 0)
        let highestDay = max(dayFit.count - 1, headerIndices.max() ?? 0)
        let dayCount = highestDay - lowestDay + 1
        let periodCount = periodFit.count
        guard dayCountRange.contains(dayCount), periodCountRange.contains(periodCount) else { return nil }

        // Everything that is not a header is cell content.
        let contentBoxes = clean.filter { box in
            dayNumber(in: box.text) == nil
                && timeRanges(in: box.text).isEmpty
                && !isPeriodNumberOnly(box.text)
        }

        var dayOrigin = dayFit.origin + dayFit.step * CGFloat(lowestDay)
        dayOrigin += contentShift(
            contentBoxes, vertical: daysAreRows,
            origin: dayOrigin, step: dayFit.step, count: dayCount
        )
        var periodOrigin = periodFit.origin
        periodOrigin += contentShift(
            contentBoxes, vertical: !daysAreRows,
            origin: periodOrigin, step: periodFit.step, count: periodCount
        )

        let dayAxis = OCRTableGrid.Axis(
            origin: dayOrigin, step: dayFit.step, count: dayCount, isVertical: daysAreRows
        )
        let periodAxis = OCRTableGrid.Axis(
            origin: periodOrigin, step: periodFit.step, count: periodCount, isVertical: !daysAreRows
        )

        // Text always runs horizontally, so a line straddles cells along x —
        // which is the period axis here and the day axis on a rotated layout.
        let horizontalStep = abs(daysAreRows ? periodAxis.step : dayAxis.step)
        let fragments = contentBoxes.flatMap { split($0, horizontalStep: horizontalStep) }

        var cells = Array(
            repeating: Array(repeating: [OCRCellFragment](), count: periodCount),
            count: dayCount
        )
        for fragment in fragments {
            guard let day = dayAxis.index(for: daysAreRows ? fragment.center.y : fragment.center.x),
                  let period = periodAxis.index(for: daysAreRows ? fragment.center.x : fragment.center.y)
            else { continue }
            cells[day][period].append(fragment)
        }
        for day in 0..<dayCount {
            for period in 0..<periodCount {
                cells[day][period].sort(by: readingOrder)
            }
        }

        return OCRTableGrid(
            dayAxis: dayAxis,
            periodAxis: periodAxis,
            daysAreRows: daysAreRows,
            dayNumbers: weekdays(for: dayAxis, dayBoxes: dayBoxes, daysAreRows: daysAreRows),
            periodTimes: periodTimes(in: clean, axis: periodAxis, daysAreRows: daysAreRows),
            cells: cells
        )
    }

    /// Lines inside a cell read top-to-bottom, then left-to-right for the ones
    /// that share a line (a straddling row cut into pieces).
    private static func readingOrder(_ lhs: OCRCellFragment, _ rhs: OCRCellFragment) -> Bool {
        let verticalGap: CGFloat = abs(lhs.center.y - rhs.center.y)
        if verticalGap > 0.008 { return lhs.center.y > rhs.center.y }
        return lhs.center.x < rhs.center.x
    }

    // MARK: - Orientation

    /// Days stacked down the side ⇒ days are rows. With too few day headers to
    /// tell, fall back to the period-number header: it always runs along the
    /// period axis, so days are whatever is left.
    private static func detectDaysAreRows(_ boxes: [OCRTextBox], dayBoxes: [OCRTextBox]) -> Bool {
        if dayBoxes.count >= 2 {
            let xs = dayBoxes.map(\.midX)
            let ys = dayBoxes.map(\.midY)
            let spreadX = (xs.max() ?? 0) - (xs.min() ?? 0)
            let spreadY = (ys.max() ?? 0) - (ys.min() ?? 0)
            if abs(spreadX - spreadY) > 0.02 { return spreadY > spreadX }
        }
        let horizontalNumbers = bestPositions([numericHeaderCandidate(boxes, vertical: false)])
        if horizontalNumbers != nil { return true }
        let verticalNumbers = bestPositions([numericHeaderCandidate(boxes, vertical: true)])
        return verticalNumbers == nil
    }

    // MARK: - Anchor candidates

    private static func points(of boxes: [OCRTextBox], vertical: Bool) -> [(pos: CGFloat, perp: CGFloat)] {
        boxes.map { (pos: vertical ? $0.midY : $0.midX, perp: vertical ? $0.midX : $0.midY) }
    }

    /// Any line whose exact text shows up at least three times is a candidate
    /// for "one per row" — "โฮมรูม" and "พัก" both qualify here, and they
    /// cross-check each other by producing the same pitch.
    private static func repeatedTextCandidates(
        _ boxes: [OCRTextBox], vertical: Bool
    ) -> [[(pos: CGFloat, perp: CGFloat)]] {
        var groups: [String: [OCRTextBox]] = [:]
        for box in boxes {
            let key = box.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.count >= 2, !key.allSatisfy(\.isNumber) else { continue }
            groups[key, default: []].append(box)
        }
        return groups.values.filter { $0.count >= 3 }.map { points(of: $0, vertical: vertical) }
    }

    private static func numericHeaderCandidate(
        _ boxes: [OCRTextBox], vertical: Bool
    ) -> [(pos: CGFloat, perp: CGFloat)] {
        var result: [(pos: CGFloat, perp: CGFloat)] = []
        for box in boxes where isPeriodNumberOnly(box.text) {
            let fractions = periodNumberFractions(in: box.text)
            guard !fractions.isEmpty else { continue }
            if vertical {
                result.append((box.midY, box.midX))
            } else {
                for fraction in fractions {
                    result.append((box.boundingBox.minX + fraction * box.boundingBox.width, box.midY))
                }
            }
        }
        return result
    }

    private static func timeCandidate(
        _ boxes: [OCRTextBox], vertical: Bool
    ) -> [(pos: CGFloat, perp: CGFloat)] {
        var result: [(pos: CGFloat, perp: CGFloat)] = []
        for box in boxes {
            let ranges = timeRanges(in: box.text)
            guard !ranges.isEmpty else { continue }
            if vertical {
                result.append((box.midY, box.midX))
            } else {
                for range in ranges {
                    result.append((
                        box.boundingBox.minX + range.textFraction * box.boundingBox.width,
                        box.midY
                    ))
                }
            }
        }
        return result
    }

    /// Picks the candidate group that spans the axis, stays in one line across
    /// it, and has the most members.
    private static func bestPositions(_ candidates: [[(pos: CGFloat, perp: CGFloat)]]) -> [CGFloat]? {
        var best: [CGFloat]?
        for candidate in candidates where candidate.count >= 3 {
            let positions = candidate.map(\.pos)
            let perpendiculars = candidate.map(\.perp)
            guard let low = positions.min(), let high = positions.max(), high - low >= minimumSpan else { continue }
            guard let near = perpendiculars.min(), let far = perpendiculars.max(),
                  far - near <= perpendicularTolerance else { continue }
            if best == nil || positions.count > (best?.count ?? 0) { best = positions }
        }
        return best
    }

    // MARK: - Line fitting

    /// Fits `pos ≈ origin + step·index` through anchors meant to be evenly
    /// spaced. The pitch comes from the *smallest* gap, not the average, so a
    /// group with a missing member ("โฮมรูม" read on only 3 of 5 rows) still
    /// gives the right answer instead of a step twice too large.
    private static func fitAxis(
        positions raw: [CGFloat], vertical: Bool
    ) -> (origin: CGFloat, step: CGFloat, count: Int)? {
        let sorted = vertical ? raw.sorted(by: >) : raw.sorted(by: <)
        var clustered: [CGFloat] = []
        for position in sorted {
            if let last = clustered.last, abs(position - last) < clusterTolerance {
                clustered[clustered.count - 1] = (last + position) / 2
            } else {
                clustered.append(position)
            }
        }
        guard clustered.count >= 2 else { return nil }

        let gaps = zip(clustered.dropFirst(), clustered).map { $0 - $1 }
        let smallest = gaps.map(abs).min() ?? 0
        guard smallest > 0.005 else { return nil }
        let unitFits = gaps.allSatisfy { gap in
            let multiple = (abs(gap) / smallest).rounded()
            return abs(abs(gap) - multiple * smallest) <= fitTolerance * smallest
        }
        let pitch = unitFits ? smallest : abs(median(gaps))
        guard pitch > 0.005 else { return nil }
        let step: CGFloat = vertical ? -pitch : pitch

        let indices = clustered.map { CGFloat(Int((($0 - clustered[0]) / step).rounded())) }
        guard let lowest = indices.min(), let highest = indices.max(), highest > lowest else { return nil }

        // Least squares through (index, position) — refits the pitch using
        // every anchor, so one noisy gap can't skew the whole axis.
        let meanIndex = indices.reduce(0, +) / CGFloat(indices.count)
        let meanPosition = clustered.reduce(0, +) / CGFloat(clustered.count)
        var numerator: CGFloat = 0
        var denominator: CGFloat = 0
        for (index, position) in zip(indices, clustered) {
            numerator += (index - meanIndex) * (position - meanPosition)
            denominator += (index - meanIndex) * (index - meanIndex)
        }
        guard denominator > 0 else { return nil }
        let fittedStep = numerator / denominator
        guard abs(fittedStep) > 0.005 else { return nil }
        let fittedOrigin = meanPosition - fittedStep * meanIndex

        let worst = zip(indices, clustered)
            .map { abs($1 - (fittedOrigin + fittedStep * $0)) }
            .max() ?? 0
        guard worst <= fitTolerance * abs(fittedStep) else { return nil }

        return (
            origin: fittedOrigin + fittedStep * lowest,
            step: fittedStep,
            count: Int(highest - lowest) + 1
        )
    }

    /// A row's anchor label is not in the middle of the row — the subject code
    /// sits at the top, the room at the bottom. Nudge the fitted line onto the
    /// centre of gravity of the real content so the ±½-step bands land on the
    /// cells instead of straddling two of them.
    private static func contentShift(
        _ boxes: [OCRTextBox], vertical: Bool, origin: CGFloat, step: CGFloat, count: Int
    ) -> CGFloat {
        var residuals: [CGFloat] = []
        for box in boxes {
            let position = vertical ? box.midY : box.midX
            let index = ((position - origin) / step).rounded()
            guard index >= 0, index <= CGFloat(count - 1) else { continue }
            residuals.append(position - (origin + step * index))
        }
        guard !residuals.isEmpty else { return 0 }
        let shift = median(residuals)
        return abs(shift) < abs(step) * 0.4 ? shift : 0
    }

    // MARK: - Splitting straddling lines

    /// Cuts a line that is far too wide for one cell into the pieces that
    /// belong to different cells, placing each by where its characters sit.
    /// Split fragments lose Vision's alternative readings — acceptable, since
    /// straddling lines are teacher/time rows, not subject codes.
    private static func split(_ box: OCRTextBox, horizontalStep: CGFloat) -> [OCRCellFragment] {
        let whole = OCRCellFragment(
            text: box.text.trimmingCharacters(in: .whitespacesAndNewlines),
            candidates: box.candidates,
            center: CGPoint(x: box.midX, y: box.midY),
            source: box
        )
        guard horizontalStep > 0, box.boundingBox.width > straddleFactor * horizontalStep else { return [whole] }

        let pieces = splitPoints(of: box.text)
        guard pieces.count > 1 else { return [whole] }
        return pieces.map { piece in
            OCRCellFragment(
                text: piece.text,
                candidates: [piece.text],
                center: CGPoint(
                    x: box.boundingBox.minX + piece.fraction * box.boundingBox.width,
                    y: box.midY
                ),
                source: box
            )
        }
    }

    /// Whitespace first; failing that, a run-together teacher list like
    /// "ครูประทุมวรรครูปรางค์ทิพย์" is cut before every "ครู" after the first.
    private static func splitPoints(of text: String) -> [(text: String, fraction: CGFloat)] {
        let byWhitespace = tokens(in: text)
        if byWhitespace.count > 1 { return byWhitespace }
        return splitOnTeacherPrefix(text)
    }

    private static func splitOnTeacherPrefix(_ text: String) -> [(text: String, fraction: CGFloat)] {
        let ns = text as NSString
        var starts: [Int] = []
        var searchFrom = 0
        while searchFrom < ns.length {
            let found = ns.range(
                of: "ครู",
                range: NSRange(location: searchFrom, length: ns.length - searchFrom)
            )
            guard found.location != NSNotFound else { break }
            starts.append(found.location)
            searchFrom = found.location + max(found.length, 1)
        }
        guard starts.count >= 2 else { return tokens(in: text) }
        if starts[0] != 0 { starts.insert(0, at: 0) }

        var result: [(text: String, fraction: CGFloat)] = []
        for (offset, start) in starts.enumerated() {
            let end = offset + 1 < starts.count ? starts[offset + 1] : ns.length
            let piece = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !piece.isEmpty else { continue }
            result.append((piece, (CGFloat(start) + CGFloat(end)) / 2 / CGFloat(ns.length)))
        }
        return result
    }

    // MARK: - Labelling

    /// Rows are consecutive weekdays, so one readable header places all of
    /// them. The most common offset wins when headers disagree.
    private static func weekdays(
        for axis: OCRTableGrid.Axis, dayBoxes: [OCRTextBox], daysAreRows: Bool
    ) -> [Int] {
        var labelled: [Int: Int] = [:]
        for box in dayBoxes {
            guard let weekday = dayNumber(in: box.text),
                  let index = axis.index(for: daysAreRows ? box.midY : box.midX)
            else { continue }
            labelled[index] = weekday
        }
        let offset = mostCommon(labelled.map { $0.value - $0.key }) ?? 1
        return (0..<axis.count).map { index in
            labelled[index] ?? min(max(index + offset, 1), 7)
        }
    }

    /// Reads every printed period and pins it to a column, then fills the gaps
    /// from the neighbours — flagged as inferred so the caller can mark those
    /// entries for review instead of presenting a guess as a reading.
    private static func periodTimes(
        in boxes: [OCRTextBox], axis: OCRTableGrid.Axis, daysAreRows: Bool
    ) -> [Int: OCRTableGrid.PeriodTime] {
        var times: [Int: OCRTableGrid.PeriodTime] = [:]
        for box in boxes {
            for range in timeRanges(in: box.text) {
                let position = daysAreRows
                    ? box.boundingBox.minX + range.textFraction * box.boundingBox.width
                    : box.midY
                guard let index = axis.index(for: position), times[index] == nil else { continue }
                times[index] = OCRTableGrid.PeriodTime(start: range.start, end: range.end, isInferred: false)
            }
        }
        guard !times.isEmpty else { return times }

        let durations = times.values.map { CGFloat($0.end - $0.start) }
        let fallback = max(Int(median(durations)), 10)
        for index in 0..<axis.count where times[index] == nil {
            guard let previous = times[index - 1] else { continue }
            times[index] = OCRTableGrid.PeriodTime(
                start: previous.end, end: previous.end + fallback, isInferred: true
            )
        }
        for index in stride(from: axis.count - 1, through: 0, by: -1) where times[index] == nil {
            guard let next = times[index + 1] else { continue }
            times[index] = OCRTableGrid.PeriodTime(
                start: max(next.start - fallback, 0), end: next.start, isInferred: true
            )
        }
        return times
    }

    // MARK: - Small helpers

    private static func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }

    private static func mostCommon<T: Hashable>(_ values: [T]) -> T? {
        var counts: [T: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        return counts.max { $0.value < $1.value }?.key
    }
}
