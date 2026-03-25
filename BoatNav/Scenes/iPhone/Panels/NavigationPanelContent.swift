import SwiftUI

struct NavigationPanelContent: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @Binding var panelDetent: PanelDetent
    @Binding var activePanel: ActivePanel
    @State private var showSearchField = false
    @State private var favoriteName = ""
    @State private var favoriteDescription = ""

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("Navigatie")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.bottom, 16)

            if navigationViewModel.isNavigating, let route = navigationViewModel.currentRoute {
                activeNavigationContent(route: route)
            } else {
                routePlanningContent
            }
        }
        .sheet(isPresented: $navigationViewModel.showAddFavoriteSheet) {
            addFavoriteSheet
        }
    }

    // MARK: - Route Planning

    private var routePlanningContent: some View {
        VStack(spacing: 16) {
            // Error
            if let error = navigationViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            // Start location card
            locationCard(
                label: "Start",
                icon: "circle.fill",
                iconColor: .green,
                selection: navigationViewModel.startSelection,
                placeholder: "Kies startlocatie",
                menuContent: {
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
                        withAnimation { panelDetent = .expanded }
                    } label: {
                        Label("Zoek locatie", systemImage: "magnifyingglass")
                    }

                    Button {
                        navigationViewModel.startMapSelection(for: .start)
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            panelDetent = .collapsed
                        }
                    } label: {
                        Label("Kies op kaart", systemImage: "mappin.and.ellipse")
                    }
                }
            )

            // Destination card
            locationCard(
                label: "Bestemming",
                icon: "flag.fill",
                iconColor: .red,
                selection: navigationViewModel.destinationSelection,
                placeholder: "Kies bestemming",
                menuContent: {
                    Button {
                        navigationViewModel.selectingFor = .destination
                        navigationViewModel.searchQuery = ""
                        navigationViewModel.searchResults = []
                        showSearchField = true
                        withAnimation { panelDetent = .expanded }
                    } label: {
                        Label("Zoek locatie", systemImage: "magnifyingglass")
                    }

                    Button {
                        navigationViewModel.startMapSelection(for: .destination)
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            panelDetent = .collapsed
                        }
                    } label: {
                        Label("Kies op kaart", systemImage: "mappin.and.ellipse")
                    }
                }
            )

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
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(
                navigationViewModel.startSelection == .none
                || navigationViewModel.destinationSelection == .none
                || navigationViewModel.isLoadingRoute
            )
            .opacity(
                (navigationViewModel.startSelection == .none
                || navigationViewModel.destinationSelection == .none)
                ? 0.5 : 1
            )

            // Save route button
            if navigationViewModel.startSelection != .none && navigationViewModel.destinationSelection != .none {
                Button {
                    navigationViewModel.saveCurrentRoute()
                } label: {
                    HStack {
                        Spacer()
                        Label("Route opslaan", systemImage: "bookmark")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            // Search results
            if !navigationViewModel.searchResults.isEmpty {
                sectionHeader("Zoekresultaten")
                VStack(spacing: 2) {
                    ForEach(navigationViewModel.searchResults) { result in
                        Button {
                            navigationViewModel.selectSearchResult(result)
                            showSearchField = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(result.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // Favorites
            favoritesSection

            // Saved routes
            savedRoutesSection

            Spacer(minLength: 20)
        }
    }

    // MARK: - Components

    private func locationCard<MenuContent: View>(
        label: String,
        icon: String,
        iconColor: Color,
        selection: NavigationViewModel.LocationSelection,
        placeholder: String,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 12))
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if selection == .none {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(selection.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            Spacer()

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.quaternary, in: Circle())
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var searchField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))

                TextField(
                    navigationViewModel.selectingFor == .start
                        ? "Zoek startlocatie..."
                        : "Zoek bestemming...",
                    text: $navigationViewModel.searchQuery
                )
                .textFieldStyle(.plain)
                .font(.subheadline)
                .autocorrectionDisabled()
                .onChange(of: navigationViewModel.searchQuery) { _, _ in
                    navigationViewModel.performSearch()
                }

                if !navigationViewModel.searchQuery.isEmpty {
                    Button {
                        navigationViewModel.searchQuery = ""
                        navigationViewModel.searchResults = []
                        showSearchField = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            if navigationViewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var favoritesSection: some View {
        VStack(spacing: 8) {
            HStack {
                sectionHeader("Favorieten")
                Spacer()
                Button {
                    navigationViewModel.showAddFavoriteSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(.blue.opacity(0.1), in: Circle())
                }
            }

            if navigationViewModel.favorites.isEmpty {
                Text("Nog geen favorieten")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(navigationViewModel.favorites) { fav in
                        Button {
                            navigationViewModel.selectFavorite(fav, for: navigationViewModel.selectingFor)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.system(size: 14))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fav.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !fav.description.isEmpty {
                                        Text(fav.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    if let idx = navigationViewModel.favorites.firstIndex(where: { $0.id == fav.id }) {
                                        navigationViewModel.deleteFavorite(at: IndexSet(integer: idx))
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var savedRoutesSection: some View {
        Group {
            if !navigationViewModel.savedRoutes.isEmpty {
                VStack(spacing: 8) {
                    sectionHeader("Opgeslagen routes")

                    VStack(spacing: 2) {
                        ForEach(navigationViewModel.savedRoutes) { route in
                            HStack {
                                Button {
                                    navigationViewModel.loadSavedRoute(route)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(route.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
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
                                        .foregroundStyle(.red.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Active Navigation

    private func activeNavigationContent(route: WaterwayRoute) -> some View {
        VStack(spacing: 16) {
            // Route summary cards
            HStack(spacing: 10) {
                statCard(value: route.distanceString, label: "Afstand")
                statCard(value: route.summary, label: "Tijd")
                statCard(value: "\(route.bridges.count)", label: "Bruggen")
                statCard(value: "\(route.locks.count)", label: "Sluizen")
            }

            // Warnings
            if !route.warnings.isEmpty {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Waarschuwingen (\(route.warnings.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Spacer()
                    }

                    ForEach(route.warnings) { warning in
                        HStack(spacing: 10) {
                            Image(systemName: warningIcon(for: warning.type))
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .frame(width: 28)

                            Text(warning.message)
                                .font(.caption)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(14)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }

            // Maneuvers
            sectionHeader("Route-instructies")

            VStack(spacing: 2) {
                ForEach(Array(route.maneuvers.enumerated()), id: \.offset) { _, maneuver in
                    HStack(spacing: 12) {
                        maneuverIcon(for: maneuver.type)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(maneuver.instruction)
                                .font(.subheadline)
                            if maneuver.distanceFromPrevious > 0 {
                                Text(String(format: "%.0f m", maneuver.distanceFromPrevious))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Stop navigation button
            Button(role: .destructive) {
                navigationViewModel.stopNavigation()
            } label: {
                HStack {
                    Spacer()
                    Label("Stop navigatie", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.red)
            }

            Spacer(minLength: 20)
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> some View {
        switch type {
        case .depart:
            Image(systemName: "location.fill").foregroundStyle(.green)
        case .turn(let direction):
            switch direction {
            case .left: Image(systemName: "arrow.turn.up.left").foregroundStyle(.blue)
            case .right: Image(systemName: "arrow.turn.up.right").foregroundStyle(.blue)
            case .slightLeft: Image(systemName: "arrow.up.left").foregroundStyle(.blue)
            case .slightRight: Image(systemName: "arrow.up.right").foregroundStyle(.blue)
            case .straight: Image(systemName: "arrow.up").foregroundStyle(.blue)
            }
        case .bridge:
            Image(systemName: "arrow.up.and.down.square.fill").foregroundStyle(.orange)
        case .lock:
            Image(systemName: "door.left.hand.closed").foregroundStyle(.purple)
        case .arrive:
            Image(systemName: "flag.checkered").foregroundStyle(.red)
        }
    }

    private func warningIcon(for type: RouteWarning.WarningType) -> String {
        switch type {
        case .bridgeTooLow: return "arrow.up.and.down.circle"
        case .lockTooNarrow: return "arrow.left.and.right.circle"
        case .lockTooShort: return "ruler"
        case .draftTooDeep: return "water.waves.and.arrow.down"
        }
    }

    // MARK: - Add Favorite Sheet

    private var addFavoriteSheet: some View {
        NavigationStack {
            Form {
                Section("Locatie toevoegen aan favorieten") {
                    TextField("Naam (bijv. Jachthaven Westergoot)", text: $favoriteName)
                    TextField("Omschrijving (optioneel)", text: $favoriteDescription)
                }

                Section("Locatie kiezen") {
                    if navigationViewModel.destinationSelection != .none {
                        Button {
                            guard let coord = navigationViewModel.destinationSelection.coordinate else { return }
                            navigationViewModel.addFavorite(
                                name: favoriteName.isEmpty ? navigationViewModel.destinationSelection.displayName : favoriteName,
                                description: favoriteDescription,
                                coordinate: coord
                            )
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        } label: {
                            Label("Gebruik huidige bestemming: \(navigationViewModel.destinationSelection.displayName)", systemImage: "flag.fill")
                        }
                        .disabled(favoriteName.isEmpty && navigationViewModel.destinationSelection.displayName.isEmpty)
                    }

                    if navigationViewModel.startSelection != .none,
                       navigationViewModel.startSelection != .currentLocation {
                        Button {
                            guard let coord = navigationViewModel.startSelection.coordinate else { return }
                            navigationViewModel.addFavorite(
                                name: favoriteName.isEmpty ? navigationViewModel.startSelection.displayName : favoriteName,
                                description: favoriteDescription,
                                coordinate: coord
                            )
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        } label: {
                            Label("Gebruik startlocatie: \(navigationViewModel.startSelection.displayName)", systemImage: "circle.fill")
                        }
                        .disabled(favoriteName.isEmpty && navigationViewModel.startSelection.displayName.isEmpty)
                    }

                    Button {
                        navigationViewModel.showAddFavoriteSheet = false
                        navigationViewModel.startMapSelection(for: .destination)
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            panelDetent = .collapsed
                        }
                    } label: {
                        Label("Kies op kaart", systemImage: "mappin.and.ellipse")
                    }
                }

                Section {
                    Text("Tip: selecteer eerst een bestemming via zoeken of de kaart, en voeg die dan toe als favoriet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Favoriet toevoegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") {
                        favoriteName = ""
                        favoriteDescription = ""
                        navigationViewModel.showAddFavoriteSheet = false
                    }
                }
            }
        }
    }
}
