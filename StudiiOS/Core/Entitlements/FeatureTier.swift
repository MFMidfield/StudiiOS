//
//  FeatureTier.swift
//  Models the app's monetization tiers so feature modules can gate UI
//  consistently: Free (always available offline), Pro (one-time purchase,
//  productivity/personalization/reporting), Plus (subscription, ongoing
//  cloud/cross-device costs). See StudentOS_รวมเอกสาร.md "โมเดลธุรกิจ".
//

import SwiftUI

enum FeatureTier: String, Codable {
    case free
    case pro
    case plus

    var label: String {
        switch self {
        case .free: return "FREE"
        case .pro: return "PRO"
        case .plus: return "PLUS"
        }
    }

    var color: Color {
        switch self {
        case .free: return Theme.Colors.success
        case .pro: return Theme.Colors.warning
        case .plus: return Theme.Colors.purple
        }
    }
}

/// Central place to check whether the current user can use a given feature.
/// V1 has no purchase flow (see "สิ่งที่ไม่รวมใน V1": no login/cloud sync),
/// so this reads from local UserDefaults set by a future StoreKit integration.
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    private let proKey = "com.studentos.entitlement.pro"
    private let plusKey = "com.studentos.entitlement.plus"

    var hasPro: Bool {
        didSet { UserDefaults.standard.set(hasPro, forKey: proKey) }
    }
    var hasPlus: Bool {
        didSet { UserDefaults.standard.set(hasPlus, forKey: plusKey) }
    }

    private init() {
        hasPro = UserDefaults.standard.bool(forKey: proKey)
        hasPlus = UserDefaults.standard.bool(forKey: plusKey)
    }

    func isUnlocked(_ tier: FeatureTier) -> Bool {
        switch tier {
        case .free: return true
        case .pro: return hasPro
        case .plus: return hasPlus
        }
    }
}
