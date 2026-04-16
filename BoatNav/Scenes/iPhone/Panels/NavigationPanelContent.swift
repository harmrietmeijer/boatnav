import SwiftUI

struct NavigationPanelContent: View {
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @Binding var panelDetent: PanelDetent
    @Binding var activePanel: ActivePanel
    @State private var showSearchField = false

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack(spacing: Design.Spacing.sm) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .foregroundStyle(navigationViewModel.isNavigating ? .white : Design.Route.wpDot)
                Text("Navigatie")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(navigationViewModel.isNavigating ? .white : Design.Route.text)
                Spacer()
            }
            .padding(.bottom, Design.Spacing.lg)

            if navigationViewModel.isNavigating, let route = navigationViewModel.currentRoute {
                activeNavigationContent(route: route)
            } else {
                routePlanningContent
            }
        }
    }

    // MARK: - Route Planning

    private var routePlanningContent: some View {
        VStack(spacing: Design.Spacing.lg) {
            // Error
            if let error = navigationViewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Design.Amber.a5)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Design.Route.text2)
                }
                .padding(Design.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tintedCard(tint: Design.Route.rowTint, border: Design.Route.border, cornerRadius: Design.Corner.sm)
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
                        withAnimation(Design.Animation.panel) {
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
                        withAnimation(Design.Animation.panel) {
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
                if SubscriptionManager.shared.canNavigate {
                    Task { await navigationViewModel.calculateRoute() }
                } else {
                    activePanel = .paywall
                }
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
            }
            .buttonStyle(.routeCTA)
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

            // Save route button — Pro only
            if navigationViewModel.startSelection != .none && navigationViewModel.destinationSelection != .none {
                Button {
                    if SubscriptionManager.shared.canSaveRoutes {
                        navigationViewModel.saveCurrentRoute()
                    } else {
                        activePanel = .paywall
                    }
                } label: {
                    HStack(spacing: 6) {
                        Label("Route opslaan", systemImage: "bookmark")
                            .font(.subheadline.weight(.medium))
                        if !SubscriptionManager.shared.canSaveRoutes {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                        }
                    }
                }
                .buttonStyle(.routeOutline)
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
                                        .foregroundStyle(Design.Route.text)
                                    Text(result.type)
                                        .font(.caption)
                                        .foregroundStyle(Design.Route.text3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(Design.Route.text3)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .routeCard()
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
                    .foregroundStyle(Design.Route.text3)

                if selection == .none {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(Design.Route.text3)
                } else {
                    Text(selection.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Design.Route.text2)
                        .lineLimit(1)
                }
            }

            Spacer()

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Design.Route.text3)
                    .frame(width: 32, height: 32)
                    .background(Design.Route.rowTint, in: Circle())
            }
        }
        .padding(Design.Spacing.lg)
        .routeCard()
    }

    private var searchField: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Design.Route.text3)
                    .font(.system(size: 14))

                TextField(
                    navigationViewModel.selectingFor == .start
                        ? "Zoek startlocatie..."
                        : "Zoek bestemming...",
                    text: $navigationViewModel.searchQuery
                )
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(Design.Route.text2)
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
                            .foregroundStyle(Design.Route.text3)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(Design.Spacing.md)
            .background(Design.Route.rowTint, in: RoundedRectangle(cornerRadius: Design.Corner.sm))

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
                    if navigationViewModel.canAddMoreFavorites {
                        navigationViewModel.showAddFavoriteSheet = true
                    } else {
                        activePanel = .paywall
                    }
                } label: {
                    Image(systemName: navigationViewModel.canAddMoreFavorites ? "plus" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.Route.text2)
                        .frame(width: 28, height: 28)
                        .background(Design.Route.rowTint, in: Circle())
                }
            }

            if navigationViewModel.favorites.isEmpty {
                Text("Nog geen favorieten")
                    .font(.caption)
                    .foregroundStyle(Design.Route.text3)
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
                                    .foregroundStyle(Design.Route.wpDot)
                                    .font(.system(size: 14))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fav.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Design.Route.text)
                                    if !fav.description.isEmpty {
                                        Text(fav.description)
                                            .font(.caption)
                                            .foregroundStyle(Design.Route.text3)
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
                                        .foregroundStyle(Design.Red.r4)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                }
                .routeCard()
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
                                    if SubscriptionManager.shared.canNavigate {
                                        Task { await navigationViewModel.calculateRoute() }
                                    } else {
                                        activePanel = .paywall
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(route.name)
                                            .font(.subheadline)
                                            .foregroundStyle(Design.Route.text)
                                        Text(route.createdAt, style: .date)
                                            .font(.system(.caption, design: .monospaced).weight(.bold))
                                            .foregroundStyle(Design.Route.text)
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
                                        .foregroundStyle(Design.Red.r4)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .routeCard()
                }
            }
        }
    }

    private func sectionHeader(_ title: String, nav: Bool = false) -> some View {
        Text(title)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(nav ? Design.Blue.b5.opacity(0.7) : Design.Route.text3)
            .textCase(.uppercase)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Active Navigation

    private func activeNavigationContent(route: WaterwayRoute) -> some View {
        VStack(spacing: 16) {
            // Route summary cards
            HStack(spacing: 10) {
                statCard(value: route.distanceString, label: "Afstand", color: Design.Blue.b5)
                statCard(value: route.timeString, label: "Tijd", color: Design.Green.g5)
                statCard(value: "\(route.bridges.count)", label: "Bruggen", color: Design.Amber.a5)
                statCard(value: "\(route.locks.count)", label: "Sluizen", color: Design.Purple.p5)
            }

            // Speed limit
            if let limit = speedViewModel.currentSpeedLimit {
                HStack(spacing: 12) {
                    // Speed limit sign
                    Text(String(format: "%.0f", limit))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(Design.Red.r4)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.white)
                                .overlay(Circle().stroke(Design.Red.r4, lineWidth: 3))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max. snelheid")
                            .font(.caption)
                            .foregroundStyle(Design.Nav.labelText)
                        Text(String(format: "%.0f km/h", limit))
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Design.Nav.dataText)
                    }

                    Spacer()

                    if speedViewModel.isExceedingLimit {
                        Label("Te snel!", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Design.Red.r4)
                    }
                }
                .padding(Design.Spacing.lg)
                .background(
                    speedViewModel.isExceedingLimit
                        ? Design.Red.r4.opacity(0.15)
                        : Design.Nav.statBg,
                    in: RoundedRectangle(cornerRadius: Design.Corner.md)
                )
            }

            // Warnings
            if !route.warnings.isEmpty {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Design.Amber.a5)
                        Text("Waarschuwingen (\(route.warnings.count))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Design.Amber.a5)
                        Spacer()
                    }

                    ForEach(route.warnings) { warning in
                        HStack(spacing: 10) {
                            Image(systemName: warningIcon(for: warning.type))
                                .font(.system(size: 14))
                                .foregroundStyle(Design.Red.r4)
                                .frame(width: 28)

                            Text(warning.message)
                                .font(.caption)
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(Design.Spacing.lg)
                .background(Color(hex: 0x1A1005).opacity(0.8), in: RoundedRectangle(cornerRadius: Design.Corner.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.Corner.md)
                        .stroke(Design.Amber.a3, lineWidth: 1)
                )
            }

            // Maneuvers
            sectionHeader("Route-instructies", nav: true)

            VStack(spacing: 2) {
                ForEach(Array(route.maneuvers.enumerated()), id: \.offset) { _, maneuver in
                    HStack(spacing: 12) {
                        maneuverIcon(for: maneuver.type)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(Design.Nav.statBg, in: RoundedRectangle(cornerRadius: Design.Corner.sm))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(maneuver.instruction)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            if maneuver.distanceFromPrevious > 0 {
                                Text(String(format: "%.0f m", maneuver.distanceFromPrevious))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Design.Blue.b5)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Design.Nav.statBg)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Design.Corner.sm))

            // Stop navigation button
            Button(role: .destructive) {
                navigationViewModel.stopNavigation()
            } label: {
                Label("Stop navigatie", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.danger)

            Spacer(minLength: 20)
        }
    }

    private func statCard(value: String, label: String, color: Color = Design.Blue.b4) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Design.Nav.dataText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Design.Nav.labelText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.md)
        .navStatCard()
    }

    @ViewBuilder
    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> some View {
        switch type {
        case .depart:
            Image(systemName: "location.fill").foregroundStyle(Design.Green.g5)
        case .turn(let direction):
            switch direction {
            case .left: Image(systemName: "arrow.turn.up.left").foregroundStyle(Design.Blue.b5)
            case .right: Image(systemName: "arrow.turn.up.right").foregroundStyle(Design.Blue.b5)
            case .slightLeft: Image(systemName: "arrow.up.left").foregroundStyle(Design.Blue.b5)
            case .slightRight: Image(systemName: "arrow.up.right").foregroundStyle(Design.Blue.b5)
            case .straight: Image(systemName: "arrow.up").foregroundStyle(Design.Blue.b5)
            }
        case .bridge:
            Image(systemName: "arrow.up.and.down.square.fill").foregroundStyle(Design.Amber.a5)
        case .lock:
            Image(systemName: "door.left.hand.closed").foregroundStyle(Design.Purple.p5)
        case .arrive:
            Image(systemName: "flag.checkered").foregroundStyle(Design.Red.r5)
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

}
