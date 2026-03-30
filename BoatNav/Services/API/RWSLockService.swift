import CoreLocation

class RWSLockService {

    struct LockInfo {
        let name: String
        let coordinate: CLLocationCoordinate2D
        let phone: String?
        let vhfChannel: String?
        let address: String?
        let city: String?
        let chambers: Int?
        let remoteOperated: Bool
    }

    struct LockStatus {
        let isrs: String
        let status: String
        let hasObstructions: Bool
        let timestamp: Date

        var displayStatus: String {
            switch status {
            case "OPERATION_STANDBY": return "In bedrijf"
            case "LOCKING_UPSTREAM", "LOCKING_DOWNSTREAM": return "Schutten"
            case "ENTERING_UPSTREAM", "ENTERING_DOWNSTREAM": return "Invaren"
            case "EXITING_UPSTREAM", "EXITING_DOWNSTREAM": return "Uitvaren"
            case "BLOCKED": return "Geblokkeerd"
            case "OUT_OF_ORDER": return "Buiten bedrijf"
            default: return status.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }

        var statusIcon: String {
            switch status {
            case "BLOCKED", "OUT_OF_ORDER": return "🔴"
            case "LOCKING_UPSTREAM", "LOCKING_DOWNSTREAM",
                 "ENTERING_UPSTREAM", "ENTERING_DOWNSTREAM",
                 "EXITING_UPSTREAM", "EXITING_DOWNSTREAM":
                return "🟡"
            case "OPERATION_STANDBY": return "🟢"
            default: return "⚪"
            }
        }
    }

    private let session: URLSession
    private var cachedLocks: [LockInfo] = []
    private var cachedStatuses: [String: LockStatus] = [:]
    private var lastStatusFetch: Date = .distantPast

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - RWS ArcGIS lock metadata

    func fetchLockMetadata() async {
        let urlString = "https://geo.rijkswaterstaat.nl/arcgis/rest/services/GDR/nwp_basisrecreatietoervaartnetwerk/FeatureServer/1/query?where=1%3D1&outFields=naam,plaatsnaam,tel_nr,marifoonka,adres,postcode,afst_bed,nr_kolken&returnGeometry=true&f=json&resultRecordCount=200&outSR=4326"

        guard let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, _) = try await session.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = json["features"] as? [[String: Any]] else { return }

            cachedLocks = features.compactMap { feature -> LockInfo? in
                guard let attrs = feature["attributes"] as? [String: Any],
                      let geo = feature["geometry"] as? [String: Any],
                      let lat = geo["y"] as? Double,
                      let lon = geo["x"] as? Double else { return nil }

                let name = attrs["naam"] as? String ?? "Onbekende sluis"
                let vhfRaw = attrs["marifoonka"] as? String ?? ""
                let vhf = vhfRaw.trimmingCharacters(in: CharacterSet(charactersIn: "[] \""))

                return LockInfo(
                    name: name,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    phone: attrs["tel_nr"] as? String,
                    vhfChannel: vhf.isEmpty ? nil : vhf,
                    address: attrs["adres"] as? String,
                    city: attrs["plaatsnaam"] as? String,
                    chambers: attrs["nr_kolken"] as? Int,
                    remoteOperated: (attrs["afst_bed"] as? String) == "Yes"
                )
            }

            print("[RWSLock] Loaded \(cachedLocks.count) locks from ArcGIS")
        } catch {
            print("[RWSLock] Failed to fetch lock metadata: \(error.localizedDescription)")
        }
    }

    // MARK: - Live lock status

    func fetchLiveStatuses() async {
        // Throttle: max once per 30 seconds
        let now = Date()
        guard now.timeIntervalSince(lastStatusFetch) >= 30 else { return }
        lastStatusFetch = now

        guard let url = URL(string: "https://www.vaarweginformatie.nl/frp/api/geodynamic/chamber/status/") else { return }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("BoatNav/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10

            let (data, _) = try await session.data(for: request)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modifications = json["modifications"] as? [[String: Any]] else { return }

            var statuses: [String: LockStatus] = [:]
            for mod in modifications {
                guard let statusObj = mod["status"] as? [String: Any],
                      let isrs = statusObj["isrs"] as? String,
                      let status = statusObj["status"] as? String else { continue }

                let timestamp = (statusObj["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
                let hasObstructions = statusObj["hasActiveObstructions"] as? Bool ?? false

                statuses[isrs] = LockStatus(isrs: isrs, status: status, hasObstructions: hasObstructions, timestamp: timestamp)
            }

            cachedStatuses = statuses
            print("[RWSLock] Live status: \(statuses.count) chambers")
        } catch {
            print("[RWSLock] Failed to fetch live status: \(error.localizedDescription)")
        }
    }

    // MARK: - Match lock data to coordinate

    /// Find RWS lock info nearest to a coordinate (within 500m)
    func lockInfo(near coordinate: CLLocationCoordinate2D) -> LockInfo? {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var bestDist = Double.infinity
        var bestLock: LockInfo?

        for lock in cachedLocks {
            let dist = loc.distance(from: CLLocation(latitude: lock.coordinate.latitude, longitude: lock.coordinate.longitude))
            if dist < bestDist && dist < 500 {
                bestDist = dist
                bestLock = lock
            }
        }
        return bestLock
    }

    /// Find nearest live status for a coordinate (within 2km, as ISRS codes cover wider area)
    func liveStatus(near coordinate: CLLocationCoordinate2D) -> LockStatus? {
        // ISRS codes contain location info but are complex to decode
        // Instead, match by finding the nearest RWS lock, then search statuses by name similarity
        guard let rwsLock = lockInfo(near: coordinate) else { return nil }

        // Search through statuses — check if any ISRS code's lock matches our name
        // ISRS format varies, so we look for any status entry that's geographically close
        // For now, return the most recent active status near this lock
        // This is a best-effort match
        return nil // Status matching requires ISRS location decoding — to be improved
    }

    /// Get enriched subtitle for a lock at a given coordinate
    func enrichedSubtitle(for coordinate: CLLocationCoordinate2D, baseSubtitle: String) -> String {
        guard let info = lockInfo(near: coordinate) else { return baseSubtitle }

        var lines: [String] = []

        // Keep existing dimension info
        if !baseSubtitle.isEmpty && baseSubtitle != "Sluis" {
            lines.append(baseSubtitle)
        }

        // Add RWS data that wasn't in the base
        if let phone = info.phone, !baseSubtitle.contains(phone) {
            lines.append("📞 \(phone)")
        }
        if let vhf = info.vhfChannel, !vhf.isEmpty, !baseSubtitle.contains("VHF") {
            lines.append("📻 VHF \(vhf)")
        }
        if let city = info.city, let addr = info.address {
            lines.append("📍 \(addr), \(city)")
        }
        if info.remoteOperated {
            lines.append("Afstandsbediend")
        }
        if let chambers = info.chambers, chambers > 1 {
            lines.append("\(chambers) kolken")
        }

        return lines.isEmpty ? "Sluis" : lines.joined(separator: "\n")
    }
}
