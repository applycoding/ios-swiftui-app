import XCTest
@testable import FleetLogCore

final class OpenMeteoWeatherProviderTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testLiveForecastDecodesCurrentConditions() async throws {
        let place = PlaceDirectory.saltLakeCity
        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            let body = """
            {"current":{"time":"2026-10-16T15:00","interval":900,"temperature_2m":61.4,"weather_code":2,"wind_speed_10m":11.5}}
            """
            return (httpResponse(url: url, status: 200), Data(body.utf8))
        }
        let provider = OpenMeteoWeatherProvider(client: makeMockHTTPClient(), fallback: ThrowingWeatherProvider())

        let weather = try await provider.forecast(for: place)

        XCTAssertEqual(weather.temperatureFahrenheit, 61.4)
        XCTAssertEqual(weather.windMilesPerHour, 11.5)
        XCTAssertEqual(weather.code, 2)
        XCTAssertEqual(weather.condition, "Partly cloudy")
        XCTAssertEqual(weather.observedAt, "2026-10-16T15:00")
        XCTAssertEqual(weather.source, .live)
    }

    func testLiveRequestTargetsOpenMeteoWithPlaceAndUnits() async throws {
        let place = PlaceDirectory.boise
        let box = RequestBox()
        URLProtocolStub.handler = { request in
            box.request = request
            let url = try XCTUnwrap(request.url)
            let body = """
            {"current":{"time":"2026-10-16T12:00","temperature_2m":70,"weather_code":0,"wind_speed_10m":4}}
            """
            return (httpResponse(url: url, status: 200), Data(body.utf8))
        }
        let provider = OpenMeteoWeatherProvider(client: makeMockHTTPClient(), fallback: ThrowingWeatherProvider())

        _ = try await provider.forecast(for: place)

        let url = try XCTUnwrap(box.request?.url)
        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(url.path, "/v1/forecast")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        let latitude = try XCTUnwrap(Double(value("latitude") ?? ""))
        let longitude = try XCTUnwrap(Double(value("longitude") ?? ""))
        XCTAssertEqual(latitude, place.latitude, accuracy: 0.0001)
        XCTAssertEqual(longitude, place.longitude, accuracy: 0.0001)
        XCTAssertEqual(value("current"), "temperature_2m,weather_code,wind_speed_10m")
        XCTAssertEqual(value("temperature_unit"), "fahrenheit")
        XCTAssertEqual(value("wind_speed_unit"), "mph")
    }

    func testServerErrorUsesSampleFallback() async throws {
        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            return (httpResponse(url: url, status: 503), Data("{\"error\":true}".utf8))
        }
        let provider = OpenMeteoWeatherProvider(client: makeMockHTTPClient(), fallback: MockWeatherProvider())

        let weather = try await provider.forecast(for: PlaceDirectory.denver)

        XCTAssertEqual(weather.source, .sample)
        XCTAssertEqual(weather.condition, WeatherCode.label(for: weather.code))
        XCTAssertEqual(weather.observedAt, "Sample forecast")
    }

    func testMalformedPayloadUsesSampleFallback() async throws {
        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            return (httpResponse(url: url, status: 200), Data("{\"current\":{}}".utf8))
        }
        let provider = OpenMeteoWeatherProvider(client: makeMockHTTPClient(), fallback: MockWeatherProvider())

        let weather = try await provider.forecast(for: PlaceDirectory.seattle)

        XCTAssertEqual(weather.source, .sample)
    }

    func testInvalidPlaceSkipsTheNetwork() async throws {
        let place = Place(name: "Nowhere", city: "Nowhere", region: "NA", latitude: 120, longitude: 10)
        let provider = OpenMeteoWeatherProvider(client: ThrowingHTTPClient(), fallback: MockWeatherProvider())

        let weather = try await provider.forecast(for: place)

        XCTAssertEqual(weather.source, .sample)
    }

    func testPrimaryErrorSurfacesWhenFallbackAlsoFails() async {
        URLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            return (httpResponse(url: url, status: 500), Data())
        }
        let provider = OpenMeteoWeatherProvider(client: makeMockHTTPClient(), fallback: ThrowingWeatherProvider())

        do {
            _ = try await provider.forecast(for: PlaceDirectory.reno)
            XCTFail("Expected the live status error.")
        } catch let error as WeatherError {
            XCTAssertEqual(error, .badStatus(500))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

final class WeatherCodeTests: XCTestCase {
    func testLabelsCoverTheWMOGroups() {
        XCTAssertEqual(WeatherCode.label(for: 0), "Clear")
        XCTAssertEqual(WeatherCode.label(for: 1), "Mainly clear")
        XCTAssertEqual(WeatherCode.label(for: 3), "Overcast")
        XCTAssertEqual(WeatherCode.label(for: 45), "Fog")
        XCTAssertEqual(WeatherCode.label(for: 55), "Drizzle")
        XCTAssertEqual(WeatherCode.label(for: 56), "Freezing drizzle")
        XCTAssertEqual(WeatherCode.label(for: 65), "Rain")
        XCTAssertEqual(WeatherCode.label(for: 67), "Freezing rain")
        XCTAssertEqual(WeatherCode.label(for: 75), "Snow")
        XCTAssertEqual(WeatherCode.label(for: 77), "Snow grains")
        XCTAssertEqual(WeatherCode.label(for: 82), "Rain showers")
        XCTAssertEqual(WeatherCode.label(for: 86), "Snow showers")
        XCTAssertEqual(WeatherCode.label(for: 95), "Thunderstorm")
        XCTAssertEqual(WeatherCode.label(for: 99), "Thunderstorm, hail")
        XCTAssertEqual(WeatherCode.label(for: 123), "Weather code 123")
    }
}

final class PlaceDirectoryTests: XCTestCase {
    func testCitiesAreUniqueAndLookupIsCaseInsensitive() {
        let cities = PlaceDirectory.all.map(\.city)
        XCTAssertEqual(Set(cities).count, cities.count)
        XCTAssertEqual(PlaceDirectory.city("  salt lake city ")?.region, "UT")
        XCTAssertNil(PlaceDirectory.city("Atlantis"))
    }
}

private final class RequestBox: @unchecked Sendable {
    var request: URLRequest?
}

private struct ThrowingWeatherProvider: WeatherProviding {
    public func forecast(for place: Place) async throws -> DestinationWeather {
        throw WeatherError.transport("sample unavailable")
    }
}

private struct ThrowingHTTPClient: HTTPClient {
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw WeatherError.transport("network should not be called")
    }
}
