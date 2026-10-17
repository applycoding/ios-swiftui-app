import XCTest
@testable import FleetLogCore

@MainActor
final class TripListViewModelTests: XCTestCase {
    func testLoadSortsDelayedThenEnRouteThenScheduled() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = InMemoryTripRepository(trips: [
            sampleTrip(reference: "NL-S", status: .scheduled, etaOffset: 4, now: now),
            sampleTrip(reference: "NL-D", status: .delayed, etaOffset: 20, now: now),
            sampleTrip(reference: "NL-E", status: .enRoute, etaOffset: 8, now: now)
        ])
        let model = TripListViewModel(repository: repository, now: { now })

        await model.load()

        XCTAssertEqual(model.phase, .loaded)
        XCTAssertEqual(model.visibleTrips.map(\.reference), ["NL-D", "NL-E", "NL-S"])
        XCTAssertEqual(model.summaryLine, "1 en route · 1 delayed · 1 scheduled")
    }

    func testLoadFailureOnAnEmptyBoardSurfacesTheMessage() async {
        let repository = InMemoryTripRepository()
        repository.error = .saveFailed("The trip store is offline.")
        let model = TripListViewModel(repository: repository)

        await model.load()

        XCTAssertEqual(model.phase, .failed("The trip store is offline."))
        XCTAssertTrue(model.trips.isEmpty)
    }

    func testReloadFailureKeepsTheTripsAlreadyOnTheBoard() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = sampleTrip(reference: "NL-1042", status: .enRoute, etaOffset: 3, now: now)
        let repository = ScriptedTripRepository(pages: [
            .success([existing]),
            .failure(TripStoreError.saveFailed("disk full"))
        ])
        let model = TripListViewModel(repository: repository)

        await model.load()
        await model.load()

        XCTAssertEqual(model.phase, .failed("disk full"))
        XCTAssertEqual(model.trips.map(\.reference), ["NL-1042"])
    }

    func testFilterAndSearchNarrowTheBoard() async {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = InMemoryTripRepository(trips: [
            sampleTrip(reference: "NL-1042", status: .enRoute, etaOffset: 3, now: now, driver: "Amina Okonkwo", cargo: "Medical imaging kits"),
            sampleTrip(reference: "NL-1108", status: .delayed, etaOffset: 9, now: now, driver: "Luis Herrera", cargo: "Kiln-dried lumber"),
            sampleTrip(reference: "NL-0761", status: .delivered, etaOffset: -2, now: now, driver: "Malik Wright", cargo: "Clinic resupply")
        ])
        let model = TripListViewModel(repository: repository)
        await model.load()

        model.filter = .delayed
        XCTAssertEqual(model.visibleTrips.map(\.reference), ["NL-1108"])

        model.filter = .all
        model.query = "okonkwo"
        XCTAssertEqual(model.visibleTrips.map(\.reference), ["NL-1042"])

        model.query = "imaging"
        XCTAssertEqual(model.visibleTrips.map(\.cargo), ["Medical imaging kits"])

        model.query = "no-such-lane"
        XCTAssertTrue(model.visibleTrips.isEmpty)
        XCTAssertFalse(model.trips.isEmpty)
    }

    func testAddPersistsAScheduledTripAndRejectsABadDraft() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let id = UUID(uuidString: "20000000-0000-0000-0000-000000000009")!
        let repository = InMemoryTripRepository()
        let model = TripListViewModel(repository: repository, now: { now }, makeID: { id })

        let rejected = await model.add(NewTripDraft(reference: "nl-1"))
        XCTAssertEqual(rejected, "Enter the driver.")
        XCTAssertTrue(repository.trips.isEmpty)

        let draft = NewTripDraft(
            reference: " nl-2210 ",
            driverName: "Evan Brooks",
            vehicleUnit: "512",
            originCity: "Seattle",
            destinationCity: "Boise",
            cargo: "Refrigerated produce",
            miles: "550"
        )
        let message = await model.add(draft)

        XCTAssertNil(message)
        XCTAssertEqual(model.phase, .loaded)
        let savedTrips = try await repository.allTrips()
        let saved = try XCTUnwrap(savedTrips.first)
        XCTAssertEqual(saved.id, id)
        XCTAssertEqual(saved.reference, "NL-2210")
        XCTAssertEqual(saved.status, .scheduled)
        XCTAssertEqual(saved.origin.city, "Seattle")
        XCTAssertEqual(saved.destination.city, "Boise")
        XCTAssertEqual(saved.miles, 550)
        XCTAssertEqual(saved.eta.timeIntervalSince(now), 10 * 3600)
        XCTAssertEqual(model.visibleTrips.map(\.reference), ["NL-2210"])
    }

    func testDeleteRemovesATripAndAStoreErrorLeavesItInPlace() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trip = sampleTrip(reference: "NL-0874", status: .scheduled, etaOffset: 4, now: now)
        let repository = InMemoryTripRepository(trips: [trip])
        let model = TripListViewModel(repository: repository)
        await model.load()

        repository.error = .saveFailed("locked")
        await model.delete(id: trip.id)
        XCTAssertEqual(model.phase, .failed("locked"))
        XCTAssertEqual(model.trips.map(\.id), [trip.id])

        repository.error = nil
        await model.delete(id: trip.id)
        XCTAssertEqual(model.phase, .loaded)
        XCTAssertTrue(model.trips.isEmpty)
        let remaining = try await repository.allTrips()
        XCTAssertEqual(remaining, [])
    }

    func testValidationMessagesAndSameCityDraft() {
        XCTAssertEqual(NewTripDraft().validationMessage, "Enter a trip reference.")
        let sameCity = NewTripDraft(
            reference: "NL-1",
            driverName: "Nora Chen",
            vehicleUnit: "12",
            originCity: "Reno",
            destinationCity: "reno",
            cargo: "Paper",
            miles: "10"
        )
        XCTAssertEqual(sameCity.validationMessage, "Origin and destination need to be different cities.")
        XCTAssertNil(sameCity.makeTrip(id: UUID(), now: Date()))

        let badMiles = NewTripDraft(
            reference: "NL-2",
            driverName: "Nora Chen",
            vehicleUnit: "12",
            originCity: "Reno",
            destinationCity: "Oakland",
            cargo: "Paper",
            miles: "0"
        )
        XCTAssertEqual(badMiles.validationMessage, "Enter the miles as a number greater than zero.")
    }
}

@MainActor
private final class ScriptedTripRepository: TripRepository {
    var pages: [Result<[Trip], Error>]
    init(pages: [Result<[Trip], Error>]) {
        self.pages = pages
    }

    public func allTrips() async throws -> [Trip] {
        try pages.removeFirst().get()
    }

    public func save(_ trip: Trip) async throws {}

    public func delete(id: UUID) async throws {}

    public func seedIfEmpty(_ trips: [Trip]) async throws {}
}

@MainActor
func sampleTrip(
    reference: String,
    status: TripStatus,
    etaOffset: TimeInterval,
    now: Date,
    driver: String = "Amina Okonkwo",
    cargo: String = "General freight"
) -> Trip {
    Trip(
        id: UUID(),
        reference: reference,
        driverName: driver,
        vehicleUnit: "100",
        origin: PlaceDirectory.tacoma,
        destination: PlaceDirectory.denver,
        status: status,
        departure: now,
        eta: now.addingTimeInterval(etaOffset * 3600),
        cargo: cargo,
        notes: "",
        miles: 100
    )
}
