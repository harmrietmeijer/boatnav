import Foundation

extension SubscriptionManager {

    /// Route calculation & turn-by-turn navigation
    var canNavigate: Bool { isPro }

    /// CarPlay display
    var canUseCarPlay: Bool { isPro }

    /// Free users: 1 favorite, Pro: unlimited
    var canSaveUnlimitedFavorites: Bool { isPro }

    /// Save & manage routes
    var canSaveRoutes: Bool { isPro }

    /// Bridge/lock warnings along route
    var canViewRouteWarnings: Bool { isPro }
}

/// Thread-safe gating snapshot, readable from any actor context.
/// Used by view models that aren't on @MainActor and can't read
/// `SubscriptionManager.isPro` directly.
///
/// Reads the cached pro status from UserDefaults — this value is kept in
/// sync by SubscriptionManager whenever RevenueCat reports a change.
enum FeatureGating {
    private static let cacheKey = "cached_pro_status"

    static var isProCached: Bool {
        UserDefaults.standard.bool(forKey: cacheKey)
    }

    static var canSaveUnlimitedFavorites: Bool { isProCached }
    static var canSaveRoutes: Bool { isProCached }
    static var canViewRouteWarnings: Bool { isProCached }
    static var canNavigate: Bool { isProCached }
    static var canUseCarPlay: Bool { isProCached }
    static var maxFreeFavorites: Int { 1 }
}
