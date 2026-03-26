import Foundation

extension SubscriptionManager {

    /// Route calculation & turn-by-turn navigation
    var canNavigate: Bool { isPro }

    /// CarPlay display
    var canUseCarPlay: Bool { isPro }

    /// Free users: 1 favorite, Pro: unlimited
    var canSaveUnlimitedFavorites: Bool { isPro }
    var maxFreeFavorites: Int { 1 }

    /// Save & manage routes
    var canSaveRoutes: Bool { isPro }

    /// Bridge/lock warnings along route
    var canViewRouteWarnings: Bool { isPro }
}
