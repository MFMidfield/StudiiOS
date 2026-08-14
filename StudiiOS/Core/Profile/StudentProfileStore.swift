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
    private let roomKey      = "com.studentos.profile.room"
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
    /// เช่น "5/2"
    var room: String {
        didSet { UserDefaults.standard.set(room, forKey: roomKey) }
    }
    /// เช่น "วิทย์-คณิต" — free text, not a picker: Thai study programmes vary
    /// far too much between schools to hardcode a list.
    var program: String {
        didSet { UserDefaults.standard.set(program, forKey: programKey) }
    }

    // Cached in-memory so @Observable views react automatically when changed.
    var cachedProfileImage: UIImage?

    private init() {
        firstName = UserDefaults.standard.string(forKey: firstNameKey) ?? ""
        lastName  = UserDefaults.standard.string(forKey: lastNameKey)  ?? ""
        nickname  = UserDefaults.standard.string(forKey: nicknameKey)  ?? ""
        school    = UserDefaults.standard.string(forKey: schoolKey)    ?? ""
        room      = UserDefaults.standard.string(forKey: roomKey)      ?? ""
        program   = UserDefaults.standard.string(forKey: programKey)   ?? ""
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
        room      = ""
        program   = ""
        try? FileManager.default.removeItem(at: profileImageURL)
        cachedProfileImage = nil
    }
}
