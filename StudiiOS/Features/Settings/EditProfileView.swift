//
//  EditProfileView.swift
//  แก้ไขโปรไฟล์ — รูป · ชื่อ-นามสกุล · ชื่อเล่น
//
//  Presented as a sheet from the profile card in SettingsView. It owns its own
//  NavigationStack and ยกเลิก/บันทึก buttons, which is why the card presents it
//  rather than pushing it: pushing would nest two navigation stacks.
//
//  Split out of SettingsView.swift (588 lines, 4 structs).
//

import SwiftUI
import UIKit

struct EditProfileView: View {
    @State private var profile = StudentProfileStore.shared
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var nickname: String = ""
    @State private var school: String = ""
    @State private var program: StudyProgram = .unspecified
    @State private var profileImage: UIImage?
    @State private var imageRemoved = false
    @State private var showImageSourcePicker = false
    @State private var imageSource: ProfileImagePicker.Source = .photoLibrary
    @State private var isPresentingImagePicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showImageSourcePicker = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                avatarView
                                    .frame(width: 90, height: 90)

                                Image(systemName: "camera.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Color.accentColor, in: Circle())
                                    .offset(x: 4, y: 4)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("ชื่อ-นามสกุล") {
                    TextField("ชื่อ", text: $firstName)
                    TextField("นามสกุล", text: $lastName)
                }

                Section("ชื่อเล่น") {
                    TextField("ชื่อเล่น", text: $nickname)
                }

                Section {
                    TextField("โรงเรียน", text: $school)
                    Picker("แผนการเรียน", selection: $program) {
                        ForEach(StudyProgram.selectable) { Text($0.label).tag($0) }
                    }
                } header: {
                    Text("โรงเรียน")
                } footer: {
                    Text("ไม่กรอกก็ได้ — ใช้แสดงบนโปรไฟล์อย่างเดียว · ระดับชั้นกับเทอมอยู่ที่ปุ่ม “ขึ้นชั้นแล้ว”")
                }
            }
            .navigationTitle("แก้ไขโปรไฟล์")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                firstName = profile.firstName
                lastName = profile.lastName
                nickname = profile.nickname
                school = profile.school
                program = profile.program
                profileImage = profile.cachedProfileImage
            }
            .confirmationDialog("เลือกรูปภาพจาก", isPresented: $showImageSourcePicker) {
                Button("กล้องถ่ายรูป") {
                    imageSource = .camera
                    isPresentingImagePicker = true
                }
                Button("คลังภาพ") {
                    imageSource = .photoLibrary
                    isPresentingImagePicker = true
                }
                if profileImage != nil {
                    Button("ลบรูปภาพ", role: .destructive) {
                        profileImage = nil
                        imageRemoved = true
                    }
                }
                Button("ยกเลิก", role: .cancel) {}
            }
            .sheet(isPresented: $isPresentingImagePicker) {
                ProfileImagePicker(source: imageSource) { picked in
                    profileImage = picked
                }
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let img = profileImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Theme.Colors.surfaceRaised)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func save() {
        profile.firstName = firstName.trimmingCharacters(in: .whitespaces)
        profile.lastName  = lastName.trimmingCharacters(in: .whitespaces)
        profile.nickname  = nickname.trimmingCharacters(in: .whitespaces)
        profile.school    = school.trimmingCharacters(in: .whitespaces)
        profile.program   = program
        if let img = profileImage {
            profile.saveProfileImage(img)
        } else if imageRemoved {
            profile.removeProfileImage()
        }
        dismiss()
    }
}
