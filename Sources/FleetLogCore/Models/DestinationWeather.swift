import Foundation

public enum WeatherSource: String, Equatable, Sendable {
    /// Forecast returned by the Open-Meteo API.
    case live
    /// Built-in forecast used when the live request fails.
    case sample
}

public struct DestinationWeather: Equatable, Sendable {
    public var temperatureFahrenheit: Double
    public var windMilesPerHour: Double
    public var code: Int
    public var condition: String
    public var observedAt: String
    public var source: WeatherSource

    public init(
        temperatureFahrenheit: Double,
        windMilesPerHour: Double,
        code: Int,
        condition: String,
        observedAt: String,
        source: WeatherSource
    ) {
        self.temperatureFahrenheit = temperatureFahrenheit
        self.windMilesPerHour = windMilesPerHour
        self.code = code
        self.condition = condition
        self.observedAt = observedAt
        self.source = source
    }
}

public enum WeatherCode {
    public static func label(for code: Int) -> String {
        switch code {
        case 0:
            return "Clear"
        case 1:
            return "Mainly clear"
        case 2:
            return "Partly cloudy"
        case 3:
            return "Overcast"
        case 45, 48:
            return "Fog"
        case 51, 53, 55:
            return "Drizzle"
        case 56, 57:
            return "Freezing drizzle"
        case 61, 63, 65:
            return "Rain"
        case 66, 67:
            return "Freezing rain"
        case 71, 73, 75:
            return "Snow"
        case 77:
            return "Snow grains"
        case 80, 81, 82:
            return "Rain showers"
        case 85, 86:
            return "Snow showers"
        case 95:
            return "Thunderstorm"
        case 96, 99:
            return "Thunderstorm, hail"
        default:
            return "Weather code \(code)"
        }
    }
}
