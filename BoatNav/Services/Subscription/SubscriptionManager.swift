import Foundation
import RevenueCat
import Combine

@MainActor
class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    @Published var isPro: Bool = false
    @Published var offerings: Offerings?
    @Published var isLoading: Bool = false

    private let entitlementID = "BoatNav Pro"
    private let apiKey = "test_HvdoegnVXDKqJHCSJvIlgBRlzvz"

    private let proStatusKey = "cached_pro_status"

    private init() {
        // Check owner bypass first, then cached status
        if UserDefaults.standard.bool(forKey: "owner_bypass") {
            isPro = true
        } else {
            isPro = UserDefaults.standard.bool(forKey: proStatusKey)
        }
    }

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)

        // Check entitlement on launch
        Task { await checkEntitlement() }

        // Listen for customer info changes
        Purchases.shared.delegate = PurchasesDelegateHandler.shared
        PurchasesDelegateHandler.shared.onChange = { [weak self] info in
            Task { @MainActor in
                self?.updateProStatus(from: info)
            }
        }
    }

    func checkEntitlement() async {
        // Owner bypass
        if UserDefaults.standard.bool(forKey: "owner_bypass") {
            isPro = true
            return
        }

        do {
            let info = try await Purchases.shared.customerInfo()
            updateProStatus(from: info)
        } catch {
            print("[Subscription] Error checking entitlement: \(error)")
        }
    }

    func loadOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            print("[Subscription] Error loading offerings: \(error)")
        }
        isLoading = false
    }

    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await Purchases.shared.purchase(package: package)
        updateProStatus(from: result.customerInfo)
    }

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }

        let info = try await Purchases.shared.restorePurchases()
        updateProStatus(from: info)
    }

    /// 5x tap on logo activates owner bypass
    func activateOwnerBypass() {
        UserDefaults.standard.set(true, forKey: "owner_bypass")
        isPro = true
        print("[Subscription] Owner bypass activated")
    }

    private func updateProStatus(from info: CustomerInfo) {
        // Owner bypass takes precedence
        if UserDefaults.standard.bool(forKey: "owner_bypass") {
            isPro = true
            return
        }
        let active = info.entitlements[entitlementID]?.isActive == true
        isPro = active
        UserDefaults.standard.set(active, forKey: proStatusKey)
    }
}

// MARK: - Purchases Delegate

class PurchasesDelegateHandler: NSObject, PurchasesDelegate {
    static let shared = PurchasesDelegateHandler()
    var onChange: ((CustomerInfo) -> Void)?

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        onChange?(customerInfo)
    }
}
