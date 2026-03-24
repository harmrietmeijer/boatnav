import Foundation
import Combine

class SettingsViewModel: ObservableObject {

    @Published var cruisingSpeedKmh: Double {
        didSet { UserDefaults.standard.set(cruisingSpeedKmh, forKey: "cruisingSpeedKmh") }
    }

    @Published var showBuoys: Bool {
        didSet { UserDefaults.standard.set(showBuoys, forKey: "showBuoys") }
    }

    @Published var showBridges: Bool {
        didSet { UserDefaults.standard.set(showBridges, forKey: "showBridges") }
    }

    @Published var showSeamarks: Bool {
        didSet { UserDefaults.standard.set(showSeamarks, forKey: "showSeamarks") }
    }

    init() {
        let defaults = UserDefaults.standard

        if defaults.double(forKey: "cruisingSpeedKmh") == 0 {
            defaults.set(10.0, forKey: "cruisingSpeedKmh")
        }
        if defaults.object(forKey: "showBuoys") == nil {
            defaults.set(true, forKey: "showBuoys")
        }
        if defaults.object(forKey: "showBridges") == nil {
            defaults.set(true, forKey: "showBridges")
        }
        if defaults.object(forKey: "showSeamarks") == nil {
            defaults.set(true, forKey: "showSeamarks")
        }

        self.cruisingSpeedKmh = defaults.double(forKey: "cruisingSpeedKmh")
        self.showBuoys = defaults.bool(forKey: "showBuoys")
        self.showBridges = defaults.bool(forKey: "showBridges")
        self.showSeamarks = defaults.bool(forKey: "showSeamarks")
    }
}
