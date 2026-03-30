import CoreLocation
import Combine

class LocationSharingViewModel: ObservableObject {

    @Published var isSharing: Bool {
        didSet { UserDefaults.standard.set(isSharing, forKey: "locationSharing_isSharing") }
    }
    @Published var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: "locationSharing_displayName") }
    }
    @Published var shareCode: String {
        didSet { UserDefaults.standard.set(shareCode, forKey: "locationSharing_shareCode") }
    }
    @Published var friends: [FriendLocation] = []
    @Published var friendAnnotations: [FriendAnnotation] = []
    @Published var searchCode: String = ""
    @Published var searchResult: FriendLocation?
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var isSettingUp = false

    weak var locationService: LocationService?
    weak var navigationViewModel: NavigationViewModel?

    private let cloudService = CloudKitLocationService()
    private var cancellables = Set<AnyCancellable>()
    private var userID: String?
    private var lastUploadLocation: CLLocation?
    private var lastUploadTime: Date = .distantPast
    private var friendIDs: [(id: String, name: String)] = []

    init() {
        let defaults = UserDefaults.standard
        self.isSharing = defaults.bool(forKey: "locationSharing_isSharing")
        self.displayName = defaults.string(forKey: "locationSharing_displayName") ?? ""
        self.shareCode = defaults.string(forKey: "locationSharing_shareCode") ?? ""

        // Load cached friend IDs
        if let data = defaults.data(forKey: "locationSharing_friends"),
           let cached = try? JSONDecoder().decode([[String]].self, from: data) {
            friendIDs = cached.map { (id: $0[0], name: $0[1]) }
        }

        // Periodic friend location fetch every 30 seconds
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchFriendLocations() }
            }
            .store(in: &cancellables)

        // Initial setup
        Task {
            await resolveUserID()
            if isSharing { await fetchFriendLocations() }
        }
    }

    func startMonitoring(locationService: LocationService) {
        self.locationService = locationService

        locationService.locationPublisher
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup

    func setupSharing() async {
        await MainActor.run { isSettingUp = true }

        do {
            let uid = try await cloudService.fetchCurrentUserID()
            self.userID = uid

            // Generate share code if needed
            await MainActor.run {
                if shareCode.isEmpty {
                    shareCode = Self.generateShareCode()
                }
            }

            let profile = FriendLocation(
                userID: uid,
                displayName: displayName,
                coordinate: locationService?.currentLocation?.coordinate ?? CLLocationCoordinate2D(),
                heading: 0,
                lastUpdated: Date(),
                isSharing: true
            )

            await cloudService.saveProfile(profile, shareCode: shareCode)
            await MainActor.run {
                isSharing = true
                isSettingUp = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Log in bij iCloud om locatie te delen"
                isSettingUp = false
            }
        }
    }

    func stopSharing() {
        isSharing = false
        guard let uid = userID else { return }
        Task { await cloudService.setSharing(userID: uid, isSharing: false) }
    }

    // MARK: - Location uploads

    private func handleLocationUpdate(_ location: CLLocation) {
        guard isSharing, let uid = userID else { return }

        let now = Date()
        // Throttle: every 15 seconds and > 25m moved
        guard now.timeIntervalSince(lastUploadTime) >= 15 else { return }
        if let last = lastUploadLocation, location.distance(from: last) < 25 { return }

        lastUploadTime = now
        lastUploadLocation = location
        let heading = locationService?.heading?.trueHeading ?? 0

        Task {
            await cloudService.updateLocation(
                userID: uid,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                heading: heading
            )
        }
    }

    // MARK: - Friend search

    func searchFriend() async {
        let code = searchCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 6 else {
            await MainActor.run { errorMessage = "Voer een 6-tekens code in" }
            return
        }

        // Detect searching for own code
        if code == shareCode.uppercased() {
            await MainActor.run { errorMessage = "Dit is je eigen code — deel deze met vrienden" }
            return
        }

        await MainActor.run {
            isSearching = true
            searchResult = nil
            errorMessage = nil
        }

        do {
            let result = try await cloudService.findByShareCode(code)
            await MainActor.run {
                if let result = result {
                    // Don't show yourself
                    if result.userID == userID {
                        errorMessage = "Dit is je eigen code — deel deze met vrienden"
                    } else {
                        searchResult = result
                    }
                } else {
                    errorMessage = "Geen gebruiker gevonden met deze code"
                }
                isSearching = false
            }
        } catch {
            print("[LocationShare] Search failed: \(error)")
            await MainActor.run {
                errorMessage = "Zoeken mislukt: \(error.localizedDescription)"
                isSearching = false
            }
        }
    }

    func addFriend(_ friend: FriendLocation) {
        guard let uid = userID else { return }
        // Don't add yourself
        guard friend.userID != uid else { return }
        // Don't add duplicates
        guard !friendIDs.contains(where: { $0.id == friend.userID }) else { return }

        friendIDs.append((id: friend.userID, name: friend.displayName))
        saveFriendIDs()
        searchResult = nil
        searchCode = ""

        Task {
            await cloudService.saveFriendLink(ownerID: uid, friendID: friend.userID, friendName: friend.displayName)
            await fetchFriendLocations()
        }
    }

    func removeFriend(_ friendID: String) {
        friendIDs.removeAll { $0.id == friendID }
        friends.removeAll { $0.userID == friendID }
        saveFriendIDs()
        rebuildAnnotations()

        guard let uid = userID else { return }
        Task { await cloudService.removeFriendLink(ownerID: uid, friendID: friendID) }
    }

    func navigateToFriend(_ friend: FriendLocation) {
        navigationViewModel?.setDestinationFromFriend(name: friend.displayName, coordinate: friend.coordinate)
    }

    // MARK: - Fetch friend locations

    func fetchFriendLocations() async {
        guard !friendIDs.isEmpty else { return }

        do {
            let ids = friendIDs.map(\.id)
            let locations = try await cloudService.fetchFriendLocations(friendIDs: ids)
            await MainActor.run {
                friends = locations
                rebuildAnnotations()
            }
        } catch {
            print("[LocationShare] Fetch friends failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func resolveUserID() async {
        do {
            userID = try await cloudService.fetchCurrentUserID()
        } catch {
            print("[LocationShare] Could not resolve user ID: \(error.localizedDescription)")
        }
    }

    private func rebuildAnnotations() {
        friendAnnotations = friends.map { FriendAnnotation(friend: $0) }
    }

    private func saveFriendIDs() {
        let data = friendIDs.map { [$0.id, $0.name] }
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "locationSharing_friends")
        }
    }

    private static func generateShareCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // No I/O/0/1 to avoid confusion
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
