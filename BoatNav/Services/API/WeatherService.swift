import Foundation
import CoreLocation

class WeatherService {

    struct WeatherData {
        let temperature: Double        // °C
        let weatherCode: Int           // WMO code
        let windSpeed: Double          // km/h
        let windDirection: Double      // degrees
        let precipitation: Double      // mm/h
        let windGusts: Double          // km/h

        var beaufort: Int {
            switch windSpeed {
            case ..<1:    return 0
            case ..<6:    return 1
            case ..<12:   return 2
            case ..<20:   return 3
            case ..<29:   return 4
            case ..<39:   return 5
            case ..<50:   return 6
            case ..<62:   return 7
            case ..<75:   return 8
            case ..<89:   return 9
            case ..<103:  return 10
            case ..<118:  return 11
            default:      return 12
            }
        }

        var windDirectionLabel: String {
            let directions = ["N", "NO", "O", "ZO", "Z", "ZW", "W", "NW"]
            let index = Int((windDirection + 22.5) / 45.0) % 8
            return directions[index]
        }

        var weatherIcon: String {
            switch weatherCode {
            case 0:          return "sun.max.fill"
            case 1, 2:       return "cloud.sun.fill"
            case 3:          return "cloud.fill"
            case 45, 48:     return "cloud.fog.fill"
            case 51...57:    return "cloud.drizzle.fill"
            case 61...67:    return "cloud.rain.fill"
            case 71...77:    return "cloud.snow.fill"
            case 80...82:    return "cloud.heavyrain.fill"
            case 85, 86:     return "cloud.snow.fill"
            case 95, 96, 99: return "cloud.bolt.rain.fill"
            default:         return "cloud.fill"
            }
        }

        var weatherDescription: String {
            switch weatherCode {
            case 0:          return "Helder"
            case 1:          return "Licht bewolkt"
            case 2:          return "Half bewolkt"
            case 3:          return "Bewolkt"
            case 45, 48:     return "Mist"
            case 51...57:    return "Motregen"
            case 61...65:    return "Regen"
            case 66, 67:     return "IJzel"
            case 71...77:    return "Sneeuw"
            case 80...82:    return "Buien"
            case 95, 96, 99: return "Onweer"
            default:         return "Onbekend"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCurrentWeather(at location: CLLocationCoordinate2D) async throws -> WeatherData {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m,wind_direction_10m,precipitation,wind_gusts_10m"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]

        let (data, response) = try await session.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw WeatherError.fetchFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any] else {
            throw WeatherError.decodingFailed
        }

        return WeatherData(
            temperature: current["temperature_2m"] as? Double ?? 0,
            weatherCode: current["weather_code"] as? Int ?? 0,
            windSpeed: current["wind_speed_10m"] as? Double ?? 0,
            windDirection: current["wind_direction_10m"] as? Double ?? 0,
            precipitation: current["precipitation"] as? Double ?? 0,
            windGusts: current["wind_gusts_10m"] as? Double ?? 0
        )
    }
}

enum WeatherError: Error, LocalizedError {
    case fetchFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .fetchFailed: return "Weer ophalen mislukt"
        case .decodingFailed: return "Weerdata onleesbaar"
        }
    }
}
