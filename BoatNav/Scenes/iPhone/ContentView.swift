import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        TabView {
            MapPreviewView()
                .tabItem {
                    Label("Kaart", systemImage: "map")
                }

            SpeedDashboardView()
                .tabItem {
                    Label("Snelheid", systemImage: "speedometer")
                }

            NavigationListView()
                .tabItem {
                    Label("Navigatie", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Instellingen", systemImage: "gear")
                }
        }
        .task {
            await navigationViewModel.loadWaterwayGraph()
        }
    }
}
