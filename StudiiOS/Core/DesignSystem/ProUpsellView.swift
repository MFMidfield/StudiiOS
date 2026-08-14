//
//  ProUpsellView.swift
//  Shown in place of a Pro/Plus-gated feature when the user hasn't
//  unlocked it. V1 has no in-app purchase flow yet (see V1 Excludes:
//  no login/cloud sync/online AI), so this is a placeholder the StoreKit
//  purchase flow will replace the button's action for.
//

import SwiftUI

struct ProUpsellView: View {
    let title: String
    let description: String
    var tier: FeatureTier = .pro

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(tier.color)
            Text(title)
                .font(.title3.bold())
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            TierBadge(tier: tier)
            Button("ปลดล็อก \(tier.label)") {
                // TODO: wire to StoreKit purchase flow
            }
            .buttonStyle(.borderedProminent)
            .tint(tier.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ProUpsellView(title: "Portfolio Hub", description: "เก็บเกียรติบัตร กิจกรรม จิตอาสา และผลงานทั้งหมดในที่เดียว")
}
