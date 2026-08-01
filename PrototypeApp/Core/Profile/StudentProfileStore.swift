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

    var firstName: String {
        didSet { UserDefaults.standard.set(firstName, forKey: firstNameKey) }
    }
    var lastName: String {
        didSet { UserDefaults.standard.set(lastName, forKey: lastNameKey) }
    }
    var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: nicknameKey) }
    }

    // Cached in-memory so @Observable views react automatically when changed.
    var cachedProfileImage: UIImage?

    private init() {
        firstName = UserDefaults.standard.string(forKey: firstNameKey) ?? ""
        lastName  = UserDefaults.standard.string(forKey: lastNameKey)  ?? ""
        nickname  = UserDefaults.standard.string(forKey: nicknameKey)  ?? ""
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
        try? FileManager.default.removeItem(at: profileImageURL)
        cachedProfileImage = nil
    }
}
