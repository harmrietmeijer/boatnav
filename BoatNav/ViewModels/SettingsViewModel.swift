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

    @Published var showRestaurants: Bool {
        didSet { UserDefaults.standard.set(showRestaurants, forKey: "showRestaurants") }
    }

    @Published var showSeamarks: Bool {
        didSet { UserDefaults.standard.set(showSeamarks, forKey: "showSeamarks") }
    }

    @Published var mapStyle: MapStyle {
        didSet { UserDefaults.standard.set(mapStyle.rawValue, forKey: "mapStyle") }
    }

    init() {
        let defaults = UserDefaults.standard

        if defaults.double(forKey: "cruisingSpeedKmh") == 0 {
            defaults.set(10.0, forKey: "cruisingSpeedKmh")
        }
        if defaults.object(forKey: "showBuoys") == nil {
            defaults.set(false, forKey: "showBuoys")
        }
        if defaults.object(forKey: "showBridges") == nil {
            defaults.set(true, forKey: "showBridges")
        }
        if defaults.object(forKey: "showRestaurants") == nil {
            defaults.set(false, forKey: "showRestaurants")
        }
        if defaults.object(forKey: "showSeamarks") == nil {
            defaults.set(true, forKey: "showSeamarks")
        }

        self.cruisingSpeedKmh = defaults.double(forKey: "cruisingSpeedKmh")
        self.showBuoys = defaults.bool(forKey: "showBuoys")
        self.showBridges = defaults.bool(forKey: "showBridges")
        self.showRestaurants = defaults.bool(forKey: "showRestaurants")
        self.showSeamarks = defaults.bool(forKey: "showSeamarks")

        if let saved = defaults.string(forKey: "mapStyle"),
           let style = MapStyle(rawValue: saved) {
            self.mapStyle = style
        } else {
            self.mapStyle = .standaard
        }
    }
}
