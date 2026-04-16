import Foundation
import RevenueCat
import Combine
import UIKit

@MainActor
class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    @Published var isPro: Bool = false
    @Published var offerings: Offerings?
    @Published var isLoading: Bool = false

    private let entitlementID = "BoatNav Pro"
    private let apiKey = "test_HvdoegnVXDKqJHCSJvIlgBRlzvz"

    // Cached status (used when offline / before first RevenueCat fetch)
    private let proStatusKey = "cached_pro_status"

    // Owner bypass — obfuscated keychain keys so they're less grep-able
    // in a reverse-engineered binary. Do NOT rename without a migration.
    private let bypassKey = "com.boatnav.dev.feature_flag_7c2a"
    private let bypassDeviceKey = "com.boatnav.dev.feature_flag_7c2a_device"

    private init() {
        refreshProStatusFromLocal()
    }

    // MARK: - RevenueCat

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)

        Task { await checkEntitlement() }

        Purchases.shared.delegate = PurchasesDelegateHandler.shared
        PurchasesDelegateHandler.shared.onChange = { [weak self] info in
            Task { @MainActor in
                self?.updateProStatus(from: info)
            }
        }
    }

    func checkEntitlement() async {
        if isBypassActiveForThisDevice() {
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

    // MARK: - Owner bypass

    /// Activates Pro access for the current device only.
    /// Triggered by a hidden 5x-tap gesture on the sailboat icon.
    func activateOwnerBypass() {
        guard let deviceID = UIDevice.current.identifierForVendor?.uuidString else {
            print("[Subscription] No IDFV available; cannot bind bypass")
            return
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())

        KeychainStore.set("1", for: bypassKey)
        KeychainStore.set(deviceID, for: bypassDeviceKey)
        isPro = true

        // Mark this device in RevenueCat subscriber attributes.
        // Allows monitoring in the RevenueCat dashboard: sudden growth of
        // `bypass_activated_at` attributes indicates the gesture has leaked.
        Purchases.shared.attribution.setAttributes([
            "bypass_activated_at": timestamp,
            "bypass_device_id": deviceID
        ])

        print("[Subscription] Owner bypass activated for device \(deviceID)")
    }

    /// Clears the bypass on this device.
    func deactivateOwnerBypass() {
        KeychainStore.remove(bypassKey)
        KeychainStore.remove(bypassDeviceKey)
        Task { await checkEntitlement() }
    }

    /// True only when the bypass was activated on THIS specific device.
    /// A keychain backup copied to another device will fail the IDFV match.
    private func isBypassActiveForThisDevice() -> Bool {
        guard KeychainStore.get(bypassKey) == "1" else { return false }
        guard let boundID = KeychainStore.get(bypassDeviceKey),
              let currentID = UIDevice.current.identifierForVendor?.uuidString
        else { return false }
        return boundID == currentID
    }

    // MARK: - Private

    private func refreshProStatusFromLocal() {
        if isBypassActiveForThisDevice() {
            isPro = true
        } else {
            isPro = UserDefaults.standard.bool(forKey: proStatusKey)
        }
    }

    private func updateProStatus(from info: CustomerInfo) {
        if isBypassActiveForThisDevice() {
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
