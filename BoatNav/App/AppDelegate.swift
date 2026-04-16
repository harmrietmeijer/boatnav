import UIKit
import CarPlay

class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Shared Services

    let locationService = LocationService()
    let speedCalculator = SpeedCalculator()
    let pdokClient = PDOKClient()
    let tileOverlayProvider = TileOverlayProvider()
    let buoyAnnotationProvider: BuoyAnnotationProvider
    let nowPlayingService = NowPlayingService()
    let rwsLockService = RWSLockService()

    // MARK: - Shared ViewModels

    let mapViewModel: MapViewModel
    let speedViewModel: SpeedViewModel
    let navigationViewModel: NavigationViewModel
    let settingsViewModel = SettingsViewModel()
    let boatProfileViewModel = BoatProfileViewModel()
    let weatherViewModel: WeatherViewModel
    let hazardReportViewModel = HazardReportViewModel()
    let locationSharingViewModel = LocationSharingViewModel()

    override init() {
        self.buoyAnnotationProvider = BuoyAnnotationProvider(pdokClient: pdokClient)

        self.mapViewModel = MapViewModel(
            tileOverlayProvider: tileOverlayProvider,
            buoyAnnotationProvider: buoyAnnotationProvider,
            pdokClient: pdokClient
        )
        self.speedViewModel = SpeedViewModel(
            locationService: locationService,
            speedCalculator: speedCalculator
        )
        self.navigationViewModel = NavigationViewModel(pdokClient: pdokClient)
        self.navigationViewModel.locationService = locationService
        self.navigationViewModel.boatProfileViewModel = boatProfileViewModel
        self.navigationViewModel.speedLimitService = speedViewModel.speedLimitService
        self.weatherViewModel = WeatherViewModel(locationService: locationService)
        self.mapViewModel.rwsLockService = rwsLockService

        super.init()

        hazardReportViewModel.startMonitoring(locationService: locationService)
        locationSharingViewModel.startMonitoring(locationService: locationService)
        locationSharingViewModel.navigationViewModel = navigationViewModel
        locationService.startUpdating()
        SubscriptionManager.shared.configure()

        // Load waterway graph for routing and speed limits
        Task {
            await navigationViewModel.loadWaterwayGraph()
            await rwsLockService.fetchLockMetadata()

            // DEBUG: seed test friend in Biesbosch — remove after testing
            let cloudService = CloudKitLocationService()
            if let result = await cloudService.seedTestFriend() {
                #if DEBUG
                print("[DEBUG] Test friend created — zoek met code: \(result.shareCode)")
                #endif
            }
        }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {

        if connectingSceneSession.role == .carTemplateApplication {
            let config = UISceneConfiguration(
                name: "CarPlay",
                sessionRole: connectingSceneSession.role
            )
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        let config = UISceneConfiguration(
            name: "iPhone",
            sessionRole: connectingSceneSession.role
        )
        return config
    }
}
