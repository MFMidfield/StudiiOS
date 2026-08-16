//
//  OnboardingIntroView.swift
//  หน้าแรกของ setup — บอกว่าแอปนี้ทำอะไรได้ ในหน้าเดียว
//
//  The old welcome was four swipeable slides. Nobody swipes four slides; they hunt
//  for the button. So this is one screen: what the app does, in the order a student
//  will meet it, then a single call to action.
//
//  Also reachable from Settings ("ดูหน้าแนะนำแอปอีกครั้ง") — that is why the button
//  title and its action are parameters instead of being wired to the flow.
//

import SwiftUI

struct OnboardingIntroView: View {
    var actionTitle: String = "เริ่มต้นใช้งาน"
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            step: .intro,
            primaryTitle: actionTitle,
            onPrimary: onContinue
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(Feature.all) { feature in
                    featureRow(feature)
                }
                offlineNote
            }
        }
    }

    // MARK: - Pieces

    private func featureRow(_ feature: Feature) -> some View {
        CardContainer {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                IconTile(systemName: feature.icon, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(Theme.Font.plex(15, .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(feature.detail)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var offlineNote: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text("ทำงานได้โดยไม่ต้องต่อเน็ต ไม่ต้องล็อกอิน ข้อมูลอยู่ในเครื่องคุณเท่านั้น")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.primarySoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: - Content

    private struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String

        /// หนึ่งบรรทัดต่อหนึ่งแท็บ/โมดูลจริงในแอป — อย่าโฆษณาอะไรที่ยังไม่มี
        static let all: [Feature] = [
            Feature(icon: "calendar",
                    title: "ตารางเรียนและงานที่ต้องส่ง",
                    detail: "ถ่ายรูปตารางจากโรงเรียนแล้วให้แอปอ่านให้ · เตือนก่อนถึงกำหนดส่ง"),
            Feature(icon: "chart.line.uptrend.xyaxis",
                    title: "เกรดและ GPAX",
                    detail: "กรอกเกรดแต่ละเทอม แล้วดูว่าต้องได้เท่าไหร่ถึงจะถึงเป้า"),
            Feature(icon: "square.and.pencil",
                    title: "เขียน SOP",
                    detail: "ใส่คณะที่อยากยื่น แล้วเขียนเรียงความ SOP ในแอปได้เลย พร้อมคำแนะนำทีละหัวข้อ"),
            Feature(icon: "folder.fill",
                    title: "แฟ้มผลงาน",
                    detail: "เก็บเกียรติบัตรและกิจกรรมไว้ตั้งแต่ ม.4 ไม่ต้องมาไล่หาตอน ม.6"),
            Feature(icon: "timer",
                    title: "โหมดโฟกัส",
                    detail: "จับเวลาอ่านหนังสือ และบล็อกแอปอื่นระหว่างนั้นได้"),
        ]
    }
}

#Preview {
    NavigationStack {
        OnboardingIntroView {}
    }
}
