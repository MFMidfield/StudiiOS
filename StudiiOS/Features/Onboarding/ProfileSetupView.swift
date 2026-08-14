//
//  ProfileSetupView.swift
//  Setup wizard, phase 1 of N: collects name/nickname/profile photo right
//  after onboarding. Shown once — gated by
//  AppStorage("hasCompletedProfileSetup") in RootContainerView. Later
//  phases will chain onward from "ถัดไป" instead of finishing setup.
//

import SwiftUI
import UIKit

struct ProfileSetupView: View {
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    private var profile = StudentProfileStore.shared

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var nickname = ""
    @State private var profileImage: UIImage?
    @State private var isShowingPhotoSourceMenu = false
    @State private var activePickerSource: ProfileImagePicker.Source?

    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var canContinue: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("ตั้งค่าโปรไฟล์")
                            .font(.title2.bold())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("ขั้นตอน 1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    Button {
                        isShowingPhotoSourceMenu = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            profileImageView
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.primary)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 16) {
                        TextField("ชื่อจริง", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                        TextField("นามสกุล", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                        TextField("ชื่อเล่น (ไม่บังคับ)", text: $nickname)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal, 24)
                }
            }

            Button {
                saveAndContinue()
            } label: {
                Text("ถัดไป")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.primary)
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.Colors.background)
        .confirmationDialog("เลือกรูปโปรไฟล์", isPresented: $isShowingPhotoSourceMenu, titleVisibility: .visible) {
            if isCameraAvailable {
                Button("ถ่ายรูป") { activePickerSource = .camera }
            }
            Button("เลือกจากคลังภาพ") { activePickerSource = .photoLibrary }
            Button("ยกเลิก", role: .cancel) {}
        }
        .fullScreenCover(item: $activePickerSource) { source in
            ProfileImagePicker(source: source) { image in
                profileImage = image
            }
            .ignoresSafeArea()
        }
        .onAppear {
            firstName = profile.firstName
            lastName = profile.lastName
            nickname = profile.nickname
            profileImage = profile.loadProfileImage()
        }
    }

    @ViewBuilder
    private var profileImageView: some View {
        Group {
            if let profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Theme.Colors.primary.opacity(0.12))
                    Image(systemName: "person.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Colors.primaryDeep)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
    }

    private func saveAndContinue() {
        profile.firstName = firstName.trimmingCharacters(in: .whitespaces)
        profile.lastName = lastName.trimmingCharacters(in: .whitespaces)
        profile.nickname = nickname.trimmingCharacters(in: .whitespaces)
        if let profileImage {
            profile.saveProfileImage(profileImage)
        }
        hasCompletedProfileSetup = true
    }
}

extension ProfileImagePicker.Source: Identifiable {
    var id: Self { self }
}

#Preview {
    ProfileSetupView()
}
