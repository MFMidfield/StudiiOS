//
//  GPAXRangeBar.swift
//  The floor–ceiling scale under the GPAX number: how low and how high the
//  final GPAX can still land, with today's value filled in and the target as a
//  marker on the same scale.
//
//  Split out of GPAXSummaryCard to keep that file under the 250-line mark.
//

import SwiftUI

/// x = (value − floor) / (ceiling − floor), clamped 0...1. Shows where the
/// current GPAX sits between the mathematical floor and ceiling, with the
/// target as a tick mark on the same scale.
struct GPAXRangeBar: View {
    let floor: Double
    let ceiling: Double
    let gpax: Double
    let target: Double?

    private func fraction(_ value: Double) -> CGFloat {
        guard ceiling > floor else { return 0 }
        return CGFloat(min(max((value - floor) / (ceiling - floor), 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.separator)
                Capsule()
                    .fill(Theme.Colors.primary)
                    .frame(width: geo.size.width * fraction(gpax))
                if let target {
                    // Taller than the bar so it reads as a marker on the scale
                    // rather than a segment of the fill.
                    Capsule()
                        .fill(Theme.Colors.textPrimary)
                        .frame(width: 2, height: 14)
                        .offset(x: geo.size.width * fraction(target) - 1)
                }
            }
        }
        .frame(height: 14)
    }
}
