//
//  ProfileImagePicker.swift
//  Thin UIImagePickerController wrapper used for profile photo capture.
//  allowsEditing gives the system's built-in move-and-scale crop UI for
//  both the camera and the photo library, so no custom crop UI is needed.
//

import SwiftUI
import UIKit

struct ProfileImagePicker: UIViewControllerRepresentable {
    /// Identifiable so callers can drive `.fullScreenCover(item:)` with it —
    /// AddScheduleEntrySheet and the setup screens all rely on this.
    enum Source: Identifiable {
        case camera
        case photoLibrary

        var id: Self { self }
    }

    let source: Source
    var allowsEditing: Bool = true
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source == .camera ? .camera : .photoLibrary
        picker.allowsEditing = allowsEditing
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProfileImagePicker

        init(_ parent: ProfileImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let image {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
