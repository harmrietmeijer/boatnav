import Foundation
import RevenueCat
import CloudKit
import Combine
import UIKit

@MainActor
class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    @Published var isPro: Bool = false
    @Published var offerings: Offerings?
    @Published var isLoading: Bool = false

    private let entitlementID = "BoatNav Pro"
    private let apiKey = "appl_HBGJTqaccQQnVPdwtbPIESriWIg"

    // Cached status (used when offline / before first RevenueCat fetch)
    private let proStatusKey = "cached_pro_status"

    // Owner bypass — obfuscated keychain keys so they're less grep-able
    // in a reverse-engineered binary. Do NOT rename without a migration.
    private let bypassKey = "com.boatnav.dev.feature_flag_7c2a"
    private let bypassDeviceKey = "com.boatnav.dev.feature_flag_7c2a_device"

    // CloudKit — remote bypass management
    private let cloudContainer = CKContainer(identifier: "iCloud.nl.boatnav.app")
    private let bypassRecordType = "OwnerBypass"

    private init() {
        refreshProStatusFromLocal()
    }

    // MARK: - RevenueCat

    func configure() {
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)

        // Restore purchases on first launch after install/reinstall so iPad
        // picks up a purchase made on iPhone (and vice-versa).
        let hasRestoredKey = "rc_has_restored_once"
        if !UserDefaults.standard.bool(forKey: hasRestoredKey) {
            Task {
                do {
                    let info = try await Purchases.shared.restorePurchases()
                    updateProStatus(from: info)
                    UserDefaults.standard.set(true, forKey: hasRestoredKey)
                } catch {
                    // Restore failed (offline?) — will retry next launch
                    await checkEntitlement()
                }
            }
        } else {
            Task { await checkEntitlement() }
        }

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
            UserDefaults.standard.set(true, forKey: proStatusKey)
            return
        }
        do {
            let info = try await Purchases.shared.customerInfo()
            updateProStatus(from: info)
        } catch {
            #if DEBUG
            print("[Subscription] Error checking entitlement: \(error)")
            #endif
            // On error, keep cached status — don't overwrite to false
        }
    }

    func loadOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            #if DEBUG
            print("[Subscription] Error loading offerings: \(error)")
            #endif
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
            #if DEBUG
            print("[Subscription] No IDFV available; cannot bind bypass")
            #endif
            return
        }
        let timestamp = ISO8601DateFormatter().string(from: Date())

        KeychainStore.set("1", for: bypassKey)
        KeychainStore.set(deviceID, for: bypassDeviceKey)
        isPro = true
        UserDefaults.standard.set(true, forKey: proStatusKey)

        // Mark this device in RevenueCat subscriber attributes.
        Purchases.shared.attribution.setAttributes([
            "bypass_activated_at": timestamp,
            "bypass_device_id": deviceID
        ])

        // Log to CloudKit so we can see who activated and remotely deactivate
        saveBypassToCloud(deviceID: deviceID, timestamp: timestamp)

        #if DEBUG
        print("[Subscription] Owner bypass activated for device \(deviceID)")
        #endif
    }

    /// Clears the bypass on this device.
    func deactivateOwnerBypass() {
        KeychainStore.remove(bypassKey)
        KeychainStore.remove(bypassDeviceKey)
        UserDefaults.standard.set(false, forKey: proStatusKey)
        isPro = false
        Task { await checkEntitlement() }
    }

    /// Check CloudKit if this device's bypass has been remotely deactivated.
    /// Call on app launch after configure().
    func syncBypassStatus() {
        guard isBypassActiveForThisDevice(),
              let deviceID = UIDevice.current.identifierForVendor?.uuidString
        else { return }

        let predicate = NSPredicate(format: "deviceID == %@", deviceID)
        let query = CKQuery(recordType: bypassRecordType, predicate: predicate)
        let db = cloudContainer.publicCloudDatabase

        Task {
            do {
                let (results, _) = try await db.records(matching: query, resultsLimit: 1)
                let records = results.compactMap { try? $0.1.get() }

                if let record = records.first {
                    let active = record["active"] as? Int64 ?? 1
                    if active == 0 {
                        // Remotely deactivated
                        await MainActor.run {
                            deactivateOwnerBypass()
                        }
                        #if DEBUG
                        print("[Subscription] Bypass remotely deactivated for \(deviceID)")
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("[Subscription] CloudKit bypass sync failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - CloudKit bypass logging

    private func saveBypassToCloud(deviceID: String, timestamp: String) {
        let record = CKRecord(recordType: bypassRecordType)
        record["deviceID"] = deviceID
        record["activatedAt"] = timestamp
        record["active"] = 1 as Int64
        record["deviceName"] = UIDevice.current.name

        let db = cloudContainer.publicCloudDatabase
        Task {
            do {
                try await db.save(record)
                #if DEBUG
                print("[Subscription] Bypass logged to CloudKit")
                #endif
            } catch {
                #if DEBUG
                print("[Subscription] CloudKit save failed: \(error.localizedDescription)")
                #endif
            }
        }
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
            // Ensure UserDefaults cache stays in sync with Keychain bypass
            UserDefaults.standard.set(true, forKey: proStatusKey)
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
