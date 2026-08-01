//
//  CareerDiscoveryView.swift
//  Career Discovery: สำรวจความสนใจ -> แนะนำสายอาชีพ/คณะ/ทักษะ -> Learning
//  Roadmap. Offline rule-based matching (no online AI, per V1 Excludes).
//

import SwiftUI
import SwiftData

private struct InterestOption: Identifiable {
    let id = UUID()
    let tag: String
    let icon: String
}

private struct CareerMatch {
    let career: String
    let faculty: String
    let skills: [String]
    let roadmap: [String]
}

struct CareerDiscoveryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CareerInterestResult.takenAt, order: .reverse) private var pastResults: [CareerInterestResult]

    @State private var selectedTags: Set<String> = []
    @State private var result: CareerMatch?

    private let options: [InterestOption] = [
        InterestOption(tag: "วิทยาศาสตร์", icon: "atom"),
        InterestOption(tag: "คณิตศาสตร์", icon: "function"),
        InterestOption(tag: "ศิลปะ/ออกแบบ", icon: "paintpalette.fill"),
        InterestOption(tag: "คอมพิวเตอร์", icon: "laptopcomputer"),
        InterestOption(tag: "ภาษา", icon: "character.book.closed.fill"),
        InterestOption(tag: "ธุรกิจ", icon: "chart.bar.fill"),
        InterestOption(tag: "การช่วยเหลือผู้อื่น", icon: "heart.fill"),
        InterestOption(tag: "กีฬา", icon: "figure.run"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CardContainer {
                    Text("สำรวจความสนใจของคุณ").font(.subheadline).fontWeight(.semibold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                        ForEach(options) { option in
                            InterestChip(option: option, isSelected: selectedTags.contains(option.tag)) {
                                toggle(option.tag)
                            }
                        }
                    }
                    Button("แนะนำสายอาชีพ") { generateRecommendation() }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedTags.isEmpty)
                        .frame(maxWidth: .infinity)
                }

                if let result {
                    CardContainer {
                        Label(result.career, systemImage: "briefcase.fill")
                            .font(.title3.bold())
                            .foregroundStyle(Theme.Colors.warning)
                        Text("คณะแนะนำ: \(result.faculty)").font(.subheadline)
                        Text("ทักษะที่ควรพัฒนา").font(.caption).fontWeight(.semibold)
                        ForEach(result.skills, id: \.self) { Text("• \($0)").font(.caption) }
                        Text("Learning Roadmap").font(.caption).fontWeight(.semibold).padding(.top, 4)
                        ForEach(result.roadmap, id: \.self) { Text("• \($0)").font(.caption) }
                    }
                }

                if !pastResults.isEmpty {
                    CardContainer {
                        Text("ผลลัพธ์ก่อนหน้า").font(.subheadline).fontWeight(.semibold)
                        ForEach(pastResults.prefix(3)) { past in
                            HStack {
                                Text(past.recommendedCareer).font(.caption)
                                Spacer()
                                Text(past.takenAt.thaiShortString).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Career Discovery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    private func generateRecommendation() {
        let match = CareerMatcher.match(tags: selectedTags)
        result = match
        context.insert(CareerInterestResult(
            interestTags: Array(selectedTags),
            recommendedCareer: match.career,
            recommendedFaculty: match.faculty,
            recommendedSkills: match.skills
        ))
    }
}

private struct InterestChip: View {
    let option: InterestOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(option.tag, systemImage: option.icon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.Colors.primary.opacity(0.15) : Color(.systemGray6))
                .foregroundStyle(isSelected ? Theme.Colors.primary : Theme.Colors.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Simple offline rule-based matcher — swap for a richer ruleset later.
private enum CareerMatcher {
    static func match(tags: Set<String>) -> CareerMatch {
        if tags.contains("คอมพิวเตอร์") {
            return CareerMatch(career: "วิศวกรซอฟต์แวร์ / นักพัฒนาโปรแกรม", faculty: "วิศวกรรมคอมพิวเตอร์ / วิทยาการคอมพิวเตอร์",
                                skills: ["การเขียนโปรแกรม", "ตรรกะ/คณิตศาสตร์", "การแก้ปัญหา"],
                                roadmap: ["เรียนพื้นฐานเขียนโปรแกรม", "ทำโปรเจกต์ส่วนตัว", "เข้าค่าย/แข่งขันด้านคอมพิวเตอร์"])
        }
        if tags.contains("วิทยาศาสตร์") || tags.contains("คณิตศาสตร์") {
            return CareerMatch(career: "แพทย์ / วิศวกร / นักวิจัย", faculty: "แพทยศาสตร์ / วิศวกรรมศาสตร์ / วิทยาศาสตร์",
                                skills: ["การวิเคราะห์", "คณิตศาสตร์ขั้นสูง", "การทดลอง"],
                                roadmap: ["เน้นวิชาวิทย์-คณิตให้แน่น", "เข้าร่วมชมรมวิทยาศาสตร์", "เตรียมสอบ TCAS สายวิทย์"])
        }
        if tags.contains("ศิลปะ/ออกแบบ") {
            return CareerMatch(career: "นักออกแบบ / ศิลปิน", faculty: "ศิลปกรรมศาสตร์ / มัณฑนศิลป์",
                                skills: ["การวาด/ออกแบบ", "โปรแกรมกราฟิก", "ความคิดสร้างสรรค์"],
                                roadmap: ["สร้างพอร์ตผลงานศิลปะ", "เรียนโปรแกรมออกแบบ", "เข้าร่วมประกวดงานศิลปะ"])
        }
        if tags.contains("ธุรกิจ") {
            return CareerMatch(career: "ผู้ประกอบการ / นักบริหารธุรกิจ", faculty: "บริหารธุรกิจ / บัญชี",
                                skills: ["การบริหารจัดการ", "การเงิน", "การตลาด"],
                                roadmap: ["เข้าร่วมกิจกรรมธุรกิจจำลอง", "ฝึกทำบัญชีเบื้องต้น", "อ่านหนังสือธุรกิจ"])
        }
        if tags.contains("การช่วยเหลือผู้อื่น") {
            return CareerMatch(career: "พยาบาล / นักจิตวิทยา / ครู", faculty: "พยาบาลศาสตร์ / จิตวิทยา / ครุศาสตร์",
                                skills: ["การสื่อสาร", "ความเห็นอกเห็นใจ", "การทำงานร่วมกับผู้อื่น"],
                                roadmap: ["เข้าร่วมกิจกรรมจิตอาสา", "ฝึกทักษะการสื่อสาร", "หาประสบการณ์ช่วยเหลือชุมชน"])
        }
        return CareerMatch(career: "สำรวจเพิ่มเติมตามความสนใจของคุณ", faculty: "หลากหลาย ขึ้นอยู่กับความถนัด",
                            skills: ["ลองทำกิจกรรมหลากหลายเพื่อค้นหาตัวเอง"],
                            roadmap: ["เข้าร่วมชมรม/กิจกรรมที่สนใจ", "ปรึกษาคุณครูแนะแนว"])
    }
}

#Preview {
    NavigationStack { CareerDiscoveryView() }
        .modelContainer(for: CareerInterestResult.self, inMemory: true)
}
