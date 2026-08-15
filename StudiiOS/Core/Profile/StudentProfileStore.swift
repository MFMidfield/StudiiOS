//
//  StudentProfileStore.swift
//  Holds the student's basic profile (name, nickname, profile photo).
//  Text fields live in UserDefaults; the photo is written to disk since
//  UIImage data doesn't belong in the defaults plist.
//

import SwiftUI
import UIKit

@Observable
final class StudentProfileStore {
    static let shared = StudentProfileStore()

    private let firstNameKey = "com.studentos.profile.firstName"
    private let lastNameKey  = "com.studentos.profile.lastName"
    private let nicknameKey  = "com.studentos.profile.nickname"
    private let schoolKey    = "com.studentos.profile.school"
    private let programKey   = "com.studentos.profile.program"

    var firstName: String {
        didSet { UserDefaults.standard.set(firstName, forKey: firstNameKey) }
    }
    var lastName: String {
        didSet { UserDefaults.standard.set(lastName, forKey: lastNameKey) }
    }
    var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: nicknameKey) }
    }

    // Display-only, all optional. Nothing computes from these — they exist so
    // the profile reads like a real student's, not a name in a box.
    var school: String {
        didSet { UserDefaults.standard.set(school, forKey: schoolKey) }
    }
    /// A fixed choice now (see StudyProgram). Devices that stored the old free
    /// text land on `.unspecified` unless the text happens to match a rawValue —
    /// the student re-picks it in one tap, nothing else depends on the value.
    ///
    /// ห้อง (เช่น "5/2") ถูกตัดทิ้งแล้ว: ไม่มีอะไรในแอปใช้ และไม่ได้ถามใน onboarding
    var program: StudyProgram {
        didSet { UserDefaults.standard.set(program.rawValue, forKey: programKey) }
    }

    // Cached in-memory so @Observable views react automatically when changed.
    var cachedProfileImage: UIImage?

    private init() {
        firstName = UserDefaults.standard.string(forKey: firstNameKey) ?? ""
        lastName  = UserDefaults.standard.string(forKey: lastNameKey)  ?? ""
        nickname  = UserDefaults.standard.string(forKey: nicknameKey)  ?? ""
        school    = UserDefaults.standard.string(forKey: schoolKey)    ?? ""
        program   = StudyProgram(rawValue: UserDefaults.standard.string(forKey: programKey) ?? "") ?? .unspecified
        cachedProfileImage = Self.readImageFromDisk()
    }

    private var profileImageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile.jpg")
    }

    private static func readImageFromDisk() -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile.jpg")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadProfileImage() -> UIImage? { cachedProfileImage }

    func saveProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: profileImageURL, options: .atomic)
        cachedProfileImage = image
    }

    func removeProfileImage() {
        try? FileManager.default.removeItem(at: profileImageURL)
        cachedProfileImage = nil
    }

    func reset() {
        firstName = ""
        lastName  = ""
        nickname  = ""
        school    = ""
        program   = .unspecified
        try? FileManager.default.removeItem(at: profileImageURL)
        cachedProfileImage = nil
    }
}
