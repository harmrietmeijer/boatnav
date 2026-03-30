import SwiftUI
import MapKit

struct MapPreviewView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapViewRepresentable(
                    mapViewModel: mapViewModel,
                    navigationViewModel: navigationViewModel,
                    annotations: mapViewModel.annotations,
                    hazardAnnotations: [],
                    friendAnnotations: [],
                    routeCoordinates: navigationViewModel.currentRoute?.coordinates ?? [],
                    startCoordinate: navigationViewModel.startSelection.coordinate,
                    destinationCoordinate: navigationViewModel.destinationSelection.coordinate,
                    isSelectingOnMap: navigationViewModel.isSelectingOnMap,
                    mapStyle: settingsViewModel.mapStyle,
                    showSeamarks: settingsViewModel.showSeamarks,
                    showBuoys: settingsViewModel.showBuoys,
                    showBridges: settingsViewModel.showBridges,
                    showRestaurants: settingsViewModel.showRestaurants,
                    recenterOnUser: false,
                    rwsLockService: RWSLockService()
                )
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 8) {
                    // Map selection banner
                    if navigationViewModel.isSelectingOnMap {
                        mapSelectionBanner
                    }

                    // Speed overlay
                    HStack(spacing: 20) {
                        VStack {
                            Text(String(format: "%.1f", speedViewModel.speedKmh))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("km/h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()
                            .frame(height: 50)

                        VStack {
                            Text(String(format: "%.1f", speedViewModel.speedKnots))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("knopen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("BoatNav")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var mapSelectionBanner: some View {
        HStack {
            Image(systemName: "mappin.and.ellipse")
            Text(navigationViewModel.mapSelectingFor == .start
                 ? "Tik op de kaart voor startlocatie"
                 : "Tik op de kaart voor bestemming")
                .font(.subheadline)

            Spacer()

            Button("Annuleer") {
                navigationViewModel.cancelMapSelection()
            }
            .font(.subheadline.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.blue.opacity(0.9))
        .foregroundStyle(.white)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
