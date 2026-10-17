import XCTest
@testable import FleetLogCore

@MainActor
final class SwiftDataTripRepositoryTests: XCTestCase {
    func testSeedInsertsOnceAndRoundTripsNotesStatusAndDelete() async throws {
        let container = try FleetStore.makeContainer(inMemory: true)
        let repository = SwiftDataTripRepository(context: container.mainContext)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let seed = SeedData.trips(now: now)

        try await repository.seedIfEmpty(seed)
        try await repository.seedIfEmpty(seed)

        var stored = try await repository.allTrips()
        XCTAssertEqual(Set(stored.map(\.reference)), Set(seed.map(\.reference)))
        XCTAssertEqual(stored.count, seed.count)

        guard var trip = stored.first(where: { $0.reference == "NL-1108" }) else {
            XCTFail("Expected the delayed lumber trip.")
            return
        }
        XCTAssertEqual(trip.status, .delayed)
        XCTAssertEqual(trip.origin.city, "Everett")
        XCTAssertEqual(trip.destination.city, "Denver")
        trip.notes = "Cleared the pass."
        trip.status = .enRoute
        try await repository.save(trip)

        stored = try await repository.allTrips()
        let updated = stored.first { $0.id == trip.id }
        XCTAssertEqual(updated?.notes, "Cleared the pass.")
        XCTAssertEqual(updated?.status, .enRoute)

        let extra = Trip(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
            reference: "NL-3001",
            driverName: "Evan Brooks",
            vehicleUnit: "512",
            origin: PlaceDirectory.seattle,
            destination: PlaceDirectory.boise,
            status: .scheduled,
            departure: now,
            eta: now.addingTimeInterval(3600),
            cargo: "Ice",
            notes: "",
            miles: 40
        )
        try await repository.save(extra)
        try await repository.delete(id: extra.id)
        try await repository.delete(id: extra.id)

        stored = try await repository.allTrips()
        XCTAssertNil(stored.first { $0.id == extra.id })
        XCTAssertEqual(stored.count, seed.count)
    }

    func testInMemorySeedDoesNotDuplicate() async throws {
        let repository = InMemoryTripRepository()
        let seed = SeedData.trips(now: Date(timeIntervalSince1970: 0))
        try await repository.seedIfEmpty(seed)
        try await repository.seedIfEmpty(SeedData.trips(now: Date(timeIntervalSince1970: 50)))
        let stored = try await repository.allTrips()
        XCTAssertEqual(stored.count, seed.count)
        XCTAssertEqual(stored.map(\.departure), seed.map(\.departure))
    }
}
