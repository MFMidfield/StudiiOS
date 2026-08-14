//
//  RIASECDimension.swift
//  The six Holland Code dimensions. Declaration order below IS the
//  canonical tie-break order used by RIASECScorer (see PLAN_RIASEC.md §3.2).
//

import SwiftUI

enum RIASECDimension: String, CaseIterable, Codable, Identifiable {
    case R, I, A, S, E, C

    var id: String { rawValue }

    var thaiName: String {
        switch self {
        case .R: return "ลงมือทำ"
        case .I: return "ค้นคว้า"
        case .A: return "สร้างสรรค์"
        case .S: return "ช่วยเหลือผู้อื่น"
        case .E: return "โน้มน้าวและนำ"
        case .C: return "จัดระบบ"
        }
    }

    var groupName: String {
        switch self {
        case .R: return "กลุ่มทักษะปฏิบัติการและเครื่องจักรกล"
        case .I: return "กลุ่มการค้นคว้า วิจัย และวิเคราะห์เชิงลึก"
        case .A: return "กลุ่มศิลปะสร้างสรรค์และการสื่อสาร"
        case .S: return "กลุ่มการบริการสังคม สุขภาพ และการสอน"
        case .E: return "กลุ่มการนำเสนอ ธุรกิจ และการบริหาร"
        case .C: return "กลุ่มการจัดการข้อมูลและระเบียบแบบแผน"
        }
    }

    var color: Color {
        switch self {
        case .R: return Theme.Colors.success
        case .I: return Theme.Colors.primary
        case .A: return Theme.Colors.pink
        case .S: return Theme.Colors.warning
        case .E: return Theme.Colors.purple
        case .C: return Theme.Colors.info
        }
    }

    var symbolName: String {
        switch self {
        case .R: return "wrench.and.screwdriver.fill"
        case .I: return "magnifyingglass"
        case .A: return "paintpalette.fill"
        case .S: return "heart.fill"
        case .E: return "megaphone.fill"
        case .C: return "list.bullet.rectangle.fill"
        }
    }
}
