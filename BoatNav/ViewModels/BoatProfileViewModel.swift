import SwiftUI
import PhotosUI

class BoatProfileViewModel: ObservableObject {

    @Published var profile: BoatProfile {
        didSet { profile.save() }
    }

    @Published var selectedPhotoItem: PhotosPickerItem? {
        didSet { loadPhoto() }
    }

    var avatarImage: UIImage? {
        guard let data = profile.avatarImageData else { return nil }
        return UIImage(data: data)
    }

    var isConfigured: Bool {
        !profile.name.isEmpty && profile.height > 0
    }

    init() {
        self.profile = BoatProfile.load()
    }

    private func loadPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Compress to max ~500KB
                if let uiImage = UIImage(data: data),
                   let compressed = uiImage.jpegData(compressionQuality: 0.5) {
                    await MainActor.run {
                        self.profile.avatarImageData = compressed
                    }
                }
            }
        }
    }
}
