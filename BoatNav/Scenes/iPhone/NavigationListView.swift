import SwiftUI

struct NavigationListView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel

    var body: some View {
        NavigationStack {
            Group {
                if navigationViewModel.isNavigating, let route = navigationViewModel.currentRoute {
                    activeNavigationView(route: route)
                } else {
                    destinationList
                }
            }
            .navigationTitle("Navigatie")
        }
    }

    private var destinationList: some View {
        List {
            if let error = navigationViewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            Section("Bestemmingen") {
                ForEach(navigationViewModel.availableDestinations) { destination in
                    Button {
                        startNavigation(to: destination)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(destination.name)
                                .font(.headline)
                            Text(destination.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(navigationViewModel.isLoadingRoute)
                }
            }
        }
        .overlay {
            if navigationViewModel.isLoadingRoute {
                ProgressView("Route berekenen...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func activeNavigationView(route: WaterwayRoute) -> some View {
        List {
            Section("Route") {
                LabeledContent("Afstand", value: route.distanceString)
                LabeledContent("Geschatte tijd", value: route.summary)
                LabeledContent("Bruggen", value: "\(route.bridges.count)")
                LabeledContent("Sluizen", value: "\(route.locks.count)")
            }

            Section("Manoeuvres") {
                ForEach(Array(route.maneuvers.enumerated()), id: \.offset) { _, maneuver in
                    HStack {
                        maneuverIcon(for: maneuver.type)
                            .frame(width: 30)

                        VStack(alignment: .leading) {
                            Text(maneuver.instruction)
                                .font(.subheadline)
                            if maneuver.distanceFromPrevious > 0 {
                                Text(String(format: "%.0f m", maneuver.distanceFromPrevious))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Stop navigatie", role: .destructive) {
                    navigationViewModel.stopNavigation()
                }
            }
        }
    }

    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> some View {
        Group {
            switch type {
            case .depart:
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
            case .turn(let direction):
                switch direction {
                case .left: Image(systemName: "arrow.turn.up.left").foregroundStyle(.blue)
                case .right: Image(systemName: "arrow.turn.up.right").foregroundStyle(.blue)
                case .slightLeft: Image(systemName: "arrow.up.left").foregroundStyle(.blue)
                case .slightRight: Image(systemName: "arrow.up.right").foregroundStyle(.blue)
                case .straight: Image(systemName: "arrow.up").foregroundStyle(.blue)
                }
            case .bridge:
                Image(systemName: "archway")
                    .foregroundStyle(.orange)
            case .lock:
                Image(systemName: "lock.rectangle")
                    .foregroundStyle(.purple)
            case .arrive:
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.red)
            }
        }
    }

    private func startNavigation(to destination: Waypoint) {
        Task {
            do {
                _ = try await navigationViewModel.calculateRoute(to: destination)
            } catch {
                await MainActor.run {
                    navigationViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
