//
//  AppLog.swift
//  Lightweight console logging so Few can verify behavior from the Xcode
//  console without attaching a debugger.
//

// nonisolated: called from background OCR code as well as from views.
nonisolated enum AppLog {
    static func action(_ category: String, _ message: String) {
        print("🔵 [\(category)] \(message)")
    }

    static func warn(_ category: String, _ message: String) {
        print("🟠 [\(category)] \(message)")
    }

    static func error(_ category: String, _ message: String) {
        print("🔴 [\(category)] \(message)")
    }
}
