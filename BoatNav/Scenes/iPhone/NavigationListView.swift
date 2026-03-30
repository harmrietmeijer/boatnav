import SwiftUI

struct NavigationListView: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @Binding var selectedTab: Int
    @State private var showSearchField = false
    @State private var favoriteName = ""
    @State private var favoriteDescription = ""

    var body: some View {
        NavigationStack {
            Group {
                if navigationViewModel.isNavigating, let route = navigationViewModel.currentRoute {
                    activeNavigationView(route: route)
                } else {
                    routePlanningView
                }
            }
            .navigationTitle("Navigatie")
            .overlay {
                BrandedDialog(
                    isPresented: navigationViewModel.showAddFavoriteSheet,
                    onDismiss: {
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        }
                    }
                ) {
                    addFavoriteContent
                }
            }
        }
    }

    private var addFavoriteContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Favoriet toevoegen")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        favoriteName = ""
                        favoriteDescription = ""
                        navigationViewModel.showAddFavoriteSheet = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.quaternary, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Input fields
            VStack(spacing: 10) {
                TextField("Naam (bijv. Jachthaven Westergoot)", text: $favoriteName)
                    .font(.subheadline)
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                TextField("Omschrijving (optioneel)", text: $favoriteDescription)
                    .font(.subheadline)
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Location options
            VStack(spacing: 2) {
                if navigationViewModel.destinationSelection != .none {
                    Button {
                        guard let coord = navigationViewModel.destinationSelection.coordinate else { return }
                        navigationViewModel.addFavorite(
                            name: favoriteName.isEmpty ? navigationViewModel.destinationSelection.displayName : favoriteName,
                            description: favoriteDescription,
                            coordinate: coord
                        )
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(.red)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bestemming")
                                    .font(.subheadline.weight(.medium))
                                Text(navigationViewModel.destinationSelection.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .foregroundStyle(.primary)
                }

                if navigationViewModel.startSelection != .none,
                   navigationViewModel.startSelection != .currentLocation {
                    if navigationViewModel.destinationSelection != .none {
                        Divider().padding(.leading, 56)
                    }
                    Button {
                        guard let coord = navigationViewModel.startSelection.coordinate else { return }
                        navigationViewModel.addFavorite(
                            name: favoriteName.isEmpty ? navigationViewModel.startSelection.displayName : favoriteName,
                            description: favoriteDescription,
                            coordinate: coord
                        )
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Startlocatie")
                                    .font(.subheadline.weight(.medium))
                                Text(navigationViewModel.startSelection.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .foregroundStyle(.primary)
                }

                Divider().padding(.leading, 56)

                Button {
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        navigationViewModel.showAddFavoriteSheet = false
                    }
                    navigationViewModel.mapSelectingFor = .destination
                    navigationViewModel.pendingFavoriteCoordinate = nil
                    navigationViewModel.startMapSelection(for: .destination)
                    selectedTab = 0
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("Kies op kaart")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .foregroundStyle(.primary)
            }
            .padding(.bottom, 16)

            // Tip
            Text("Selecteer eerst een bestemming via zoeken of de kaart, en voeg die dan toe als favoriet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Route Planning

    private var routePlanningView: some View {
        List {
            if let error = navigationViewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            // Start & Destination fields
            Section("Route plannen") {
                // Start location
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)

                        if navigationViewModel.startSelection == .none {
                            Text("Kies startlocatie")
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(navigationViewModel.startSelection.displayName)
                                .lineLimit(1)
                        }

                        Spacer()

                        Menu {
                            Button {
                                navigationViewModel.startSelection = .currentLocation
                            } label: {
                                Label("Huidige locatie", systemImage: "location.fill")
                            }

                            Button {
                                navigationViewModel.selectingFor = .start
                                navigationViewModel.searchQuery = ""
                                navigationViewModel.searchResults = []
                                showSearchField = true
                            } label: {
                                Label("Zoek locatie", systemImage: "magnifyingglass")
                            }

                            Button {
                                navigationViewModel.startMapSelection(for: .start)
                                selectedTab = 0
                            } label: {
                                Label("Kies op kaart", systemImage: "mappin.and.ellipse")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Destination
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bestemming")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.red)
                            .font(.caption)

                        if navigationViewModel.destinationSelection == .none {
                            Text("Kies bestemming")
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(navigationViewModel.destinationSelection.displayName)
                                .lineLimit(1)
                        }

                        Spacer()

                        Menu {
                            Button {
                                navigationViewModel.selectingFor = .destination
                                navigationViewModel.searchQuery = ""
                                navigationViewModel.searchResults = []
                                showSearchField = true
                            } label: {
                                Label("Zoek locatie", systemImage: "magnifyingglass")
                            }

                            Button {
                                navigationViewModel.startMapSelection(for: .destination)
                                selectedTab = 0
                            } label: {
                                Label("Kies op kaart", systemImage: "mappin.and.ellipse")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Search field
                if showSearchField {
                    searchField
                }

                // Calculate button
                Button {
                    Task { await navigationViewModel.calculateRoute() }
                } label: {
                    HStack {
                        Spacer()
                        if navigationViewModel.isLoadingRoute {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Bereken route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    navigationViewModel.startSelection == .none
                    || navigationViewModel.destinationSelection == .none
                    || navigationViewModel.isLoadingRoute
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                // Save route button
                if navigationViewModel.startSelection != .none && navigationViewModel.destinationSelection != .none {
                    Button {
                        navigationViewModel.saveCurrentRoute()
                    } label: {
                        Label("Route opslaan", systemImage: "bookmark")
                    }
                }
            }

            // Search results
            if !navigationViewModel.searchResults.isEmpty {
                Section("Zoekresultaten") {
                    ForEach(navigationViewModel.searchResults) { result in
                        Button {
                            navigationViewModel.selectSearchResult(result)
                            showSearchField = false
                        } label: {
                            VStack(alignment: .leading) {
                                Text(result.displayName)
                                    .font(.subheadline)
                                Text(result.type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Favorites
            Section {
                if navigationViewModel.favorites.isEmpty {
                    Text("Nog geen favorieten")
                        .foregroundStyle(.tertiary)
                        .font(.subheadline)
                } else {
                    ForEach(navigationViewModel.favorites) { fav in
                        Button {
                            navigationViewModel.selectFavorite(fav, for: navigationViewModel.selectingFor)
                        } label: {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                VStack(alignment: .leading) {
                                    Text(fav.name)
                                        .font(.headline)
                                    if !fav.description.isEmpty {
                                        Text(fav.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: navigationViewModel.deleteFavorite)
                }
            } header: {
                HStack {
                    Text("Favorieten")
                    Spacer()
                    Button {
                        navigationViewModel.showAddFavoriteSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                    }
                }
            }

            // Saved routes
            if !navigationViewModel.savedRoutes.isEmpty {
                Section("Opgeslagen routes") {
                    ForEach(navigationViewModel.savedRoutes) { route in
                        HStack {
                            Button {
                                navigationViewModel.loadSavedRoute(route)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(route.name)
                                        .font(.subheadline)
                                    Text(route.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                if let idx = navigationViewModel.savedRoutes.firstIndex(where: { $0.id == route.id }) {
                                    navigationViewModel.deleteSavedRoute(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                        }
                    }
                    .onDelete(perform: navigationViewModel.deleteSavedRoute)
                }
            }
        }
    }

    private var searchField: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    navigationViewModel.selectingFor == .start
                        ? "Zoek startlocatie..."
                        : "Zoek bestemming...",
                    text: $navigationViewModel.searchQuery
                )
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: navigationViewModel.searchQuery) { _, _ in
                    navigationViewModel.performSearch()
                }

                Button {
                    navigationViewModel.searchQuery = ""
                    navigationViewModel.searchResults = []
                    showSearchField = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            if navigationViewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Active Navigation

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
                Image(systemName: "arrow.up.and.down.square.fill")
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
}
