import Foundation

struct BoatProfile: Codable {
    var name: String
    var height: Double      // doorvaarthoogte in meters
    var beam: Double         // breedte in meters
    var draft: Double        // diepgang in meters
    var avatarImageData: Data?

    static let `default` = BoatProfile(
        name: "", height: 0, beam: 0, draft: 0, avatarImageData: nil
    )

    // MARK: - Persistence

    private static let key = "boatProfile"

    static func load() -> BoatProfile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(BoatProfile.self, from: data) else {
            return .default
        }
        return profile
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
