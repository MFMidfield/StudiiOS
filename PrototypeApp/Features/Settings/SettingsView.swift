//
//  SettingsView.swift
//  App settings: tier status (Free/Pro/Plus), theme, and app info. No
//  login/account screens — V1 is offline-first with no cloud sync.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit

struct SettingsView: View {
    @State private var entitlements = EntitlementStore.shared
    @State private var profile = StudentProfileStore.shared
    @State private var notifications = NotificationManager.shared
    @State private var isPresentingWelcome = false
    @State private var isConfirmingReset = false
    @State private var isPresentingSetupTest = false
    @State private var isPresentingEditProfile = false
    @State private var showTestNotificationHint = false
    @State private var savedSetupFlags: (profile: Bool, schedule: Bool, grade: Bool, summary: Bool)?
    @Environment(\.modelContext) private var context

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    @AppStorage("hasCompletedScheduleSetup") private var hasCompletedScheduleSetup = false
    @AppStorage("hasCompletedGradeSetup") private var hasCompletedGradeSetup = false
    @AppStorage("hasCompletedSetupSummary") private var hasCompletedSetupSummary = false
    @AppStorage("scheduleShowsPersonalTasks") private var scheduleShowsPersonalTasks = false

    @AppStorage(TermStore.activeTermKey) private var activeTermID = ""
    @Query private var terms: [Term]
    private var activeTerm: Term? { TermStore.find(idString: activeTermID, in: terms) }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    profileAvatarView
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        let fullName = [profile.firstName, profile.lastName]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        Text(fullName.isEmpty ? "ยังไม่ได้ตั้งชื่อ" : fullName)
                            .font(.headline)
                        if !profile.nickname.isEmpty {
                            Text("ชื่อเล่น: \(profile.nickname)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button("แก้ไข") {
                        isPresentingEditProfile = true
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button("ดูหน้าแนะนำแอปอีกครั้ง") {
                    isPresentingWelcome = true
                }
                Button("เปิดหน้า Setup (ทดสอบ)") {
                    startSetupTest()
                }
                Button("ตั้งค่าใหม่อีกครั้ง (Setup ใหม่)", role: .destructive) {
                    isConfirmingReset = true
                }
            }

            Section("สถานะสมาชิก") {
                HStack {
                    Text("Student OS Pro")
                    Spacer()
                    Toggle("", isOn: $entitlements.hasPro).labelsHidden()
                }
                Text("V1 ยังไม่มีระบบซื้อในแอป — สวิตช์นี้ใช้สำหรับทดสอบฟีเจอร์ระหว่างพัฒนาเท่านั้น")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("การแจ้งเตือน") {
                LabeledContent("สถานะสิทธิ์", value: authorizationStatusLabel)

                if notifications.authorizationStatus == .notDetermined {
                    Button("ขอสิทธิ์แจ้งเตือน") {
                        Task { await notifications.requestAuthorization() }
                    }
                }

                if notifications.authorizationStatus == .denied {
                    Button("เปิดตั้งค่าแจ้งเตือนของเครื่อง") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Button("ทดสอบแจ้งเตือน (5 วินาที)") {
                    Task {
                        await notifications.sendTestNotification()
                        showTestNotificationHint = true
                    }
                }
                Text("กดแล้วสลับออกจากแอปหรือรออยู่หน้านี้ก็ได้ จะเด้งใน 5 วินาที")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                NavigationLink("การแจ้งเตือนที่ตั้งไว้") {
                    PendingNotificationsView()
                }
            }

            Section("ตารางเรียน") {
                NavigationLink {
                    TermManagementView()
                } label: {
                    LabeledContent("เทอมปัจจุบัน", value: activeTerm?.displayName ?? "—")
                }
                Toggle("แสดงงานส่วนตัวในตารางเรียน", isOn: $scheduleShowsPersonalTasks)
                Text("ปิดไว้ = การ์ด \"งาน / การบ้านวันนี้\" แสดงเฉพาะการบ้าน ไม่รวมงานทั่วไป")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("เกี่ยวกับ") {
                LabeledContent("เวอร์ชัน", value: "1.0.0 (Prototype)")
                LabeledContent("โหมด", value: "Offline-first")
            }

            Section("หลักการออกแบบ") {
                Label("Offline-first", systemImage: "wifi.slash")
                Label("Privacy-first", systemImage: "lock.shield")
                Label("Thai-first", systemImage: "character.book.closed")
            }

            developerSection
        }
        .navigationTitle("ตั้งค่า")
        .task {
            await notifications.refreshStatus()
        }
        .alert("ส่งแจ้งเตือนทดสอบแล้ว", isPresented: $showTestNotificationHint) {
            Button("ตกลง", role: .cancel) { }
        } message: {
            Text("จะเด้งใน 5 วินาที ลองสลับออกจากแอปดูก็ได้")
        }
        .fullScreenCover(isPresented: $isPresentingWelcome) {
            WelcomeView()
        }
        .fullScreenCover(isPresented: $isPresentingSetupTest, onDismiss: restoreSetupFlags) {
            SetupFlowTestContainer()
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            EditProfileView()
        }
        .confirmationDialog(
            "ล้างข้อมูลทั้งหมด",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("ลบข้อมูลทั้งหมดและเริ่มใหม่", role: .destructive) {
                resetAllData()
            }
            Button("ยกเลิก", role: .cancel) {}
        } message: {
            Text("ข้อมูลทั้งหมดในแอป (วิชา, งาน, โน้ต, ตารางเรียน, เกรด, โปรไฟล์ ฯลฯ) จะถูกลบถาวร แล้วพาคุณกลับไปหน้า Welcome ใหม่")
        }
    }

    /// Kept out of `body` on purpose: `#if DEBUG` written inline inside a
    /// ViewBuilder confuses the type checker, so the conditional lives here
    /// and `body` just references the property.
    @ViewBuilder
    private var developerSection: some View {
        #if DEBUG
        Section("สำหรับนักพัฒนา") {
            NavigationLink("ทดสอบ OCR") {
                OCRDebugView()
            }
            Text("ดูว่า Vision อ่านรูปออกมาเป็นข้อความอะไรบ้าง — ไม่ขึ้นในเวอร์ชันจริง")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        #endif
    }

    private var authorizationStatusLabel: String {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "อนุญาตแล้ว"
        case .denied: return "ปิดอยู่"
        case .notDetermined: return "ยังไม่ได้ขอ"
        @unknown default: return "ไม่ทราบสถานะ"
        }
    }

    @ViewBuilder
    private var profileAvatarView: some View {
        if let img = profile.cachedProfileImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(.systemGray5))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    /// Debug-only: wipes every SwiftData record plus the local profile, then
    /// resets every onboarding/setup flag so the app restarts from Welcome.
    private func resetAllData() {
        deleteAll(Assignment.self)
        deleteAll(Note.self)
        deleteAll(Flashcard.self)
        deleteAll(GradeComponent.self)
        deleteAll(ExamEvent.self)
        deleteAll(ScheduleEntry.self)
        deleteAll(FocusSession.self)
        deleteAll(PortfolioItem.self)
        deleteAll(PortfolioImage.self)
        PortfolioImageStore.deleteAll()
        deleteAll(CareerInterestResult.self)
        deleteAll(TCASChecklistItem.self)
        deleteAll(TCASEntry.self)
        deleteAll(SemesterRecord.self)
        deleteAll(CalendarEvent.self)
        deleteAll(CalendarTag.self)
        deleteAll(CalendarAttachmentItem.self)
        deleteAll(Subject.self)
        deleteAll(DayScheduleOverride.self)
        deleteAll(TermSubject.self)
        deleteAll(Term.self)

        NotificationManager.shared.cancelAll()
        StudentProfileStore.shared.reset()

        // การบล็อกแอปเป็นค่าระดับ**ระบบ** ไม่ได้อยู่ใน SwiftData — ถ้าไม่เคลียร์
        // ตรงนี้ ล้างข้อมูลแล้วแอปอื่นจะยังถูกบล็อกค้างอยู่
        PomodoroEngine.shared.stop(recordPartial: false)
        AppBlockManager.shared.stopBlocking(reason: "ล้างข้อมูลทั้งหมด")

        PrototypeAppApp.seedBuiltInSubjects(in: context)

        hasCompletedOnboarding = false
        hasCompletedProfileSetup = false
        hasCompletedScheduleSetup = false
        hasCompletedGradeSetup = false
        hasCompletedSetupSummary = false
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        items.forEach { context.delete($0) }
    }

    /// Debug-only: temporarily marks every setup phase incomplete so the
    /// real Setup wizard (Profile → Schedule → Grade → Summary) can be
    /// clicked through again, without touching any SwiftData or profile
    /// data. The original flags are restored once the preview is dismissed.
    private func startSetupTest() {
        savedSetupFlags = (hasCompletedProfileSetup, hasCompletedScheduleSetup, hasCompletedGradeSetup, hasCompletedSetupSummary)
        hasCompletedProfileSetup = false
        hasCompletedScheduleSetup = false
        hasCompletedGradeSetup = false
        hasCompletedSetupSummary = false
        isPresentingSetupTest = true
    }

    private func restoreSetupFlags() {
        guard let saved = savedSetupFlags else { return }
        hasCompletedProfileSetup = saved.profile
        hasCompletedScheduleSetup = saved.schedule
        hasCompletedGradeSetup = saved.grade
        hasCompletedSetupSummary = saved.summary
        savedSetupFlags = nil
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileView: View {
    @State private var profile = StudentProfileStore.shared
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var nickname: String = ""
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
                .fill(Color(.systemGray5))
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
        if let img = profileImage {
            profile.saveProfileImage(img)
        } else if imageRemoved {
            profile.removeProfileImage()
        }
        dismiss()
    }
}

// MARK: - Setup Test Container

/// Debug-only: replays the Setup wizard for testing. Mirrors the phase
/// switching in `RootContainerView`, plus a floating close button so
/// testers can bail out of any phase without finishing it.
private struct SetupFlowTestContainer: View {
    @AppStorage("hasCompletedProfileSetup") private var hasCompletedProfileSetup = false
    @AppStorage("hasCompletedScheduleSetup") private var hasCompletedScheduleSetup = false
    @AppStorage("hasCompletedGradeSetup") private var hasCompletedGradeSetup = false
    @AppStorage("hasCompletedSetupSummary") private var hasCompletedSetupSummary = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !hasCompletedProfileSetup {
                ProfileSetupView()
            } else if !hasCompletedScheduleSetup {
                NavigationStack { ScheduleSetupView() }
            } else if !hasCompletedGradeSetup {
                NavigationStack { GradeReportSetupView() }
            } else if !hasCompletedSetupSummary {
                SetupSummaryView()
            } else {
                VStack(spacing: 16) {
                    Text("จบขั้นตอน Setup แล้ว (โหมดทดสอบ)")
                    Button("ปิด") { dismiss() }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}

// MARK: - Pending Notifications

private struct PendingNotificationsView: View {
    @State private var requests: [UNNotificationRequest] = []

    var body: some View {
        List {
            if requests.isEmpty {
                Text("ยังไม่มีการแจ้งเตือนที่ตั้งไว้")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requests, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.content.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                           let date = trigger.nextTriggerDate() {
                            Text(date.thaiFullString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("ล้างการแจ้งเตือนทั้งหมด", role: .destructive) {
                    NotificationManager.shared.cancelAll()
                    requests = []
                }
            }
        }
        .navigationTitle("การแจ้งเตือนที่ตั้งไว้")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            requests = await NotificationManager.shared.pendingRequests()
        }
    }
}
