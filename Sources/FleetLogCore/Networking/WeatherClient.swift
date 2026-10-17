import Foundation

public enum WeatherError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case invalidPlace
    case badStatus(Int)
    case decoding
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The weather request could not be built."
        case .invalidPlace:
            "That stop has no usable coordinates."
        case .badStatus(let status):
            "Open-Meteo returned status \(status)."
        case .decoding:
            "The weather response could not be read."
        case .transport(let message):
            message
        }
    }
}

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient, Sendable {
    public var session: URLSession

    public init(session: URLSession) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw WeatherError.transport("The weather response was not HTTP.")
            }
            return (data, http)
        } catch let error as WeatherError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw WeatherError.transport(error.localizedDescription)
        }
    }
}

public protocol WeatherProviding: Sendable {
    func forecast(for place: Place) async throws -> DestinationWeather
}

public struct MockWeatherProvider: WeatherProviding, Sendable {
    public init() {}

    public func forecast(for place: Place) async throws -> DestinationWeather {
        let band = Int(abs(place.latitude).rounded()) % 5
        let code: Int
        switch band {
        case 0:
            code = 0
        case 1:
            code = 2
        case 2:
            code = 3
        case 3:
            code = 61
        case 4:
            code = 71
        default:
            code = 2
        }
        let temperature = 48 + (place.latitude - 40) * 0.8
        let wind = 7 + abs(place.longitude).truncatingRemainder(dividingBy: 8)
        return DestinationWeather(
            temperatureFahrenheit: temperature,
            windMilesPerHour: wind,
            code: code,
            condition: WeatherCode.label(for: code),
            observedAt: "Sample forecast",
            source: .sample
        )
    }
}

/// Live destination weather from the public Open-Meteo forecast API.
/// No API key is required. A failed request returns the injected fallback.
public struct OpenMeteoWeatherProvider: WeatherProviding, Sendable {
    public var client: any HTTPClient
    public var fallback: any WeatherProviding

    public init(client: any HTTPClient, fallback: any WeatherProviding) {
        self.client = client
        self.fallback = fallback
    }

    public func forecast(for place: Place) async throws -> DestinationWeather {
        do {
            return try await liveForecast(for: place)
        } catch is CancellationError {
            throw CancellationError()
        } catch let primary {
            do {
                var sample = try await fallback.forecast(for: place)
                sample.source = .sample
                return sample
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw primary
            }
        }
    }

    private func liveForecast(for place: Place) async throws -> DestinationWeather {
        guard (-90...90).contains(place.latitude), (-180...180).contains(place.longitude) else {
            throw WeatherError.invalidPlace
        }
        let request = try makeRequest(for: place)
        let (data, response) = try await client.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw WeatherError.badStatus(response.statusCode)
        }
        let decoded: ForecastResponse
        do {
            decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
        } catch {
            throw WeatherError.decoding
        }
        return DestinationWeather(
            temperatureFahrenheit: decoded.current.temperature2m,
            windMilesPerHour: decoded.current.windSpeed10m,
            code: decoded.current.weatherCode,
            condition: WeatherCode.label(for: decoded.current.weatherCode),
            observedAt: decoded.current.time,
            source: .live
        )
    }

    private func makeRequest(for place: Place) throws -> URLRequest {
        guard var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            throw WeatherError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph")
        ]
        guard let url = components.url else {
            throw WeatherError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        return request
    }
}

private struct ForecastResponse: Decodable {
    var current: Current

    struct Current: Decodable {
        var time: String
        var temperature2m: Double
        var weatherCode: Int
        var windSpeed10m: Double

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
        }
    }
}
