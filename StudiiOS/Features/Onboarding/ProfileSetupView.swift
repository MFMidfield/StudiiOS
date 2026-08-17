//
//  ProfileSetupView.swift
//  หน้า 2 ของ setup — ชื่อ โรงเรียน ระดับชั้น เทอม แผนการเรียน
//
//  ระดับชั้นกับเทอมคือของจริงที่สุดในหน้านี้: มันเขียนสองที่พร้อมกัน
//    · GPAXSettings.setCurrentTerm  = เทอม "จริง" ของนักเรียน → หน้าเกรดใช้ตัวนี้ตัดสิน
//      ว่าเทอมไหนกรอกย้อนหลังได้ (D7)
//    · TermStore.findOrCreate + setActive = เทอมที่กำลังเปิดดู → ตารางเรียน/งานใช้ตัวนี้
//  เขียนแค่ตัวใดตัวหนึ่ง = ตารางที่กรอกหน้า 3 ไปโผล่คนละเทอมกับเกรดหน้า 4 แบบเงียบๆ
//
//  ข้ามไม่ได้ตามสเปค — ปุ่มถัดไปติดจนกว่าชื่อจริง/นามสกุล/ชื่อเล่นจะครบ
//

import SwiftUI
import SwiftData
import UIKit

struct ProfileSetupView: View {
    let onBack: () -> Void
    let onNext: () -> Void

    @Environment(\.modelContext) private var context
    @State private var profile = StudentProfileStore.shared

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var school = ""
    @State private var gradeLevel = SchoolBand.upper.gradeLevels[0]
    @State private var termNumber = 1
    @State private var program: StudyProgram = .unspecified

    @State private var profileImage: UIImage?
    @State private var isShowingPhotoSourceMenu = false
    @State private var activePickerSource: ProfileImagePicker.Source?

    private var canContinue: Bool {
        [firstName, lastName, nickname].allSatisfy {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    var body: some View {
        OnboardingScaffold(
            step: .profile,
            onBack: onBack,
            isPrimaryEnabled: canContinue,
            onPrimary: saveAndContinue
        ) {
            VStack(spacing: Theme.Spacing.xxl) {
                avatarPicker
                nameSection
                schoolSection
                termSection
                programSection
            }
        }
        .fullScreenCover(item: $activePickerSource) { source in
            ProfileImagePicker(source: source) { profileImage = $0 }
                .ignoresSafeArea()
        }
        .onAppear(perform: prefill)
    }

    // MARK: - Sections

    private var avatarPicker: some View {
        Button {
            isShowingPhotoSourceMenu = true
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    avatar
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.onPrimary)
                        .frame(width: 30, height: 30)
                        .background(Theme.Colors.primary, in: Circle())
                        .overlay(Circle().stroke(Theme.Colors.background, lineWidth: 3))
                }
                Text(profileImage == nil ? "เพิ่มรูปโปรไฟล์ (ไม่บังคับ)" : "เปลี่ยนรูป")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        // เกาะที่ปุ่มรูป ไม่ใช่ทั้งหน้า — บน iPad/Mac dialog เป็น popover ที่ต้องมี
        // ตัวชี้ ถ้าเกาะทั้งหน้ามันจะไปโผล่มุมซ้ายบน
        .confirmationDialog("รูปโปรไฟล์", isPresented: $isShowingPhotoSourceMenu, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("ถ่ายรูป") { activePickerSource = .camera }
            }
            Button("เลือกจากคลังภาพ") { activePickerSource = .photoLibrary }
            if profileImage != nil {
                Button("ลบรูป", role: .destructive) { profileImage = nil }
            }
            Button("ยกเลิก", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Theme.Colors.primarySoft)
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.Colors.primaryDeep)
                }
            }
        }
        .frame(width: 104, height: 104)
        .clipShape(Circle())
    }

    private var nameSection: some View {
        OnboardingSection(title: "ชื่อของคุณ") {
            VStack(spacing: Theme.Spacing.md) {
                OnboardingTextField(title: "ชื่อจริง", text: $firstName)
                OnboardingTextField(title: "นามสกุล", text: $lastName)
                OnboardingTextField(title: "ชื่อเล่น", placeholder: "ให้แอปเรียกคุณว่าอะไรดี", text: $nickname)
            }
        }
    }

    private var schoolSection: some View {
        OnboardingSection(title: "โรงเรียน") {
            OnboardingTextField(title: "ชื่อโรงเรียน", isOptional: true, text: $school)
        }
    }

    private var termSection: some View {
        OnboardingSection(title: "ตอนนี้เรียนอยู่") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                OnboardingChipRow(
                    title: "ระดับชั้น",
                    values: SchoolBand.upper.gradeLevels,
                    label: { "ม.\($0)" },
                    selection: $gradeLevel
                )
                OnboardingChipRow(
                    title: "เทอม",
                    footnote: "สองข้อนี้ผูกกับระบบเกรดโดยตรง — แอปใช้ตัดสินว่าเทอมไหนจบไปแล้วและกรอกเกรดย้อนหลังได้บ้าง เปลี่ยนทีหลังได้ที่ ตั้งค่า → การ์ด \"การเรียน\"",
                    values: [1, 2],
                    label: { "เทอม \($0)" },
                    selection: $termNumber
                )
            }
        }
    }

    private var programSection: some View {
        OnboardingSection(title: "แผนการเรียน") {
            OnboardingChipRow(
                title: "เลือกแผนที่ใกล้เคียงที่สุด",
                values: StudyProgram.selectable,
                label: { $0.label },
                selection: $program
            )
        }
    }

    // MARK: - Data

    private func prefill() {
        firstName = profile.firstName
        lastName = profile.lastName
        nickname = profile.nickname
        school = profile.school
        program = profile.program
        profileImage = profile.loadProfileImage()
        gradeLevel = GPAXSettings.currentGradeLevel ?? SchoolBand.upper.gradeLevels[0]
        termNumber = GPAXSettings.currentTermNumber ?? 1
    }

    private func saveAndContinue() {
        profile.firstName = firstName.trimmingCharacters(in: .whitespaces)
        profile.lastName = lastName.trimmingCharacters(in: .whitespaces)
        profile.nickname = nickname.trimmingCharacters(in: .whitespaces)
        profile.school = school.trimmingCharacters(in: .whitespaces)
        profile.program = program
        if let profileImage {
            profile.saveProfileImage(profileImage)
        } else {
            profile.removeProfileImage()
        }

        GPAXSettings.setCurrentTerm(gradeLevel: gradeLevel, termNumber: termNumber)

        let term = TermStore.findOrCreate(gradeLevel: gradeLevel, termNumber: termNumber, in: context)
        TermStore.setActive(term)
        // bootstrap() สร้างเทอม ม.4 เทอม 1 ไว้ก่อนตั้งแต่เปิดแอปครั้งแรก — ถ้านักเรียน
        // เลือกชั้นอื่น เทอมเปล่านั้นจะค้างอยู่ในหน้า "จัดการเทอม" เหมือนเทอมที่ลืมกรอก
        TermStore.pruneEmptyTerms(except: term, in: context)
        try? context.save()

        AppLog.action("Onboarding", "บันทึกโปรไฟล์ · \(term.displayName)")
        onNext()
    }
}

#Preview {
    NavigationStack {
        ProfileSetupView(onBack: {}, onNext: {})
    }
    .modelContainer(for: [Term.self, ScheduleEntry.self, TermSubject.self], inMemory: true)
}
