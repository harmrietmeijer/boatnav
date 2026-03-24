import SwiftUI

@main
struct BoatNavApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.mapViewModel)
                .environmentObject(appDelegate.speedViewModel)
                .environmentObject(appDelegate.navigationViewModel)
                .environmentObject(appDelegate.settingsViewModel)
        }
    }
}
