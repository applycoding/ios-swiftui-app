import XCTest
@testable import FleetLogCore

@MainActor
final class TripDetailViewModelTests: XCTestCase {
    func testLoadWeatherPublishesTheForecast() async {
        let trip = detailTrip()
        let model = TripDetailViewModel(
            trip: trip,
            repository: InMemoryTripRepository(trips: [trip]),
            weather: FixedWeatherProvider(result: .success(sampleWeather(source: .live)))
        )

        await model.loadWeather()

        XCTAssertEqual(model.weatherPhase, .loaded)
        XCTAssertEqual(model.weather?.source, .live)
        XCTAssertEqual(model.weather?.condition, "Clear")
    }

    func testSampleForecastStaysVisibleAsAFallback() async {
        let trip = detailTrip()
        let model = TripDetailViewModel(
            trip: trip,
            repository: InMemoryTripRepository(trips: [trip]),
            weather: FixedWeatherProvider(result: .success(sampleWeather(source: .sample)))
        )

        await model.loadWeather()

        XCTAssertEqual(model.weatherPhase, .loaded)
        XCTAssertEqual(model.weather?.source, .sample)
        XCTAssertEqual(model.weather?.observedAt, "Sample forecast")
    }

    func testWeatherFailureClearsTheForecast() async {
        let trip = detailTrip()
        let model = TripDetailViewModel(
            trip: trip,
            repository: InMemoryTripRepository(trips: [trip]),
            weather: FixedWeatherProvider(result: .failure(.transport("The station timed out.")))
        )

        await model.loadWeather()

        XCTAssertNil(model.weather)
        XCTAssertEqual(model.weatherPhase, .failed("The station timed out."))
    }

    func testSavingNotesUpdatesTheStoreAndNotifiesTheBoard() async throws {
        let trip = detailTrip(notes: "Seal checked")
        let repository = InMemoryTripRepository(trips: [trip])
        let recorder = ChangeRecorder()
        let model = TripDetailViewModel(trip: trip, repository: repository, weather: MockWeatherProvider()) { updated in
            recorder.trips.append(updated)
        }
        model.notes = "Seal checked. Receiver wants a call."
        XCTAssertTrue(model.hasUnsavedNotes)

        await model.saveNotes()

        XCTAssertFalse(model.hasUnsavedNotes)
        XCTAssertNil(model.actionError)
        XCTAssertEqual(model.trip.notes, "Seal checked. Receiver wants a call.")
        let storedTrips = try await repository.allTrips()
        let stored = try XCTUnwrap(storedTrips.first)
        XCTAssertEqual(stored.notes, "Seal checked. Receiver wants a call.")
        XCTAssertEqual(recorder.trips.map(\.notes), ["Seal checked. Receiver wants a call."])
    }

    func testStatusChangePersistsAndIgnoresTheCurrentStatus() async throws {
        let trip = detailTrip(status: .enRoute)
        let repository = InMemoryTripRepository(trips: [trip])
        let model = TripDetailViewModel(trip: trip, repository: repository, weather: MockWeatherProvider())

        await model.setStatus(.enRoute)
        XCTAssertEqual(model.trip.status, .enRoute)

        await model.setStatus(.delivered)
        XCTAssertEqual(model.trip.status, .delivered)
        XCTAssertNil(model.actionError)
        let storedTrips = try await repository.allTrips()
        let stored = try XCTUnwrap(storedTrips.first)
        XCTAssertEqual(stored.status, .delivered)
    }

    func testFailedStatusSaveLeavesTheTripUntouched() async {
        let trip = detailTrip(status: .scheduled)
        let repository = InMemoryTripRepository(trips: [trip])
        repository.error = .saveFailed("locked")
        let model = TripDetailViewModel(trip: trip, repository: repository, weather: MockWeatherProvider())

        await model.setStatus(.delayed)

        XCTAssertEqual(model.trip.status, .scheduled)
        XCTAssertEqual(model.actionError, "locked")
    }
}

@MainActor
private final class ChangeRecorder {
    var trips: [Trip] = []
}

private struct FixedWeatherProvider: WeatherProviding {
    var result: Result<DestinationWeather, WeatherError>

    public func forecast(for place: Place) async throws -> DestinationWeather {
        try result.get()
    }
}

@MainActor
private func detailTrip(status: TripStatus = .enRoute, notes: String = "") -> Trip {
    Trip(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        reference: "NL-1042",
        driverName: "Amina Okonkwo",
        vehicleUnit: "418",
        origin: PlaceDirectory.tacoma,
        destination: PlaceDirectory.saltLakeCity,
        status: status,
        departure: Date(timeIntervalSince1970: 1_700_000_000),
        eta: Date(timeIntervalSince1970: 1_700_036_000),
        cargo: "Medical imaging kits",
        notes: notes,
        miles: 812
    )
}

private func sampleWeather(source: WeatherSource) -> DestinationWeather {
    DestinationWeather(
        temperatureFahrenheit: 64,
        windMilesPerHour: 9,
        code: 0,
        condition: "Clear",
        observedAt: source == .sample ? "Sample forecast" : "2026-10-16T15:00",
        source: source
    )
}
