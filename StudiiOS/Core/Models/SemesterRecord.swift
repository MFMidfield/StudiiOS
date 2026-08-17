//
//  SemesterRecord.swift
//  One subject's final grade point + credit hours for a semester. Feeds
//  GPA Planner's GPAX calculation and future-semester simulation.
//

import Foundation
import SwiftData

@Model
final class SemesterRecord {
    var semesterLabel: String
    var subjectName: String
    var creditHours: Double
    /// Thai grade point scale: 0, 1, 1.5, 2, 2.5, 3, 3.5, 4
    var gradePoint: Double
    var isSimulated: Bool

    init(
        semesterLabel: String,
        subjectName: String,
        creditHours: Double,
        gradePoint: Double,
        isSimulated: Bool = false
    ) {
        self.semesterLabel = semesterLabel
        self.subjectName = subjectName
        self.creditHours = creditHours
        self.gradePoint = gradePoint
        self.isSimulated = isSimulated
    }
}
