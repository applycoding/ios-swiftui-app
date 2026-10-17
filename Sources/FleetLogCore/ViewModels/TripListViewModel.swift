import Foundation
import Observation

@MainActor
@Observable
public final class TripListViewModel {
    public private(set) var trips: [Trip] = []
    public private(set) var phase: LoadPhase = .idle
    public var query = ""
    public var filter: TripFilter = .all

    private let repository: any TripRepository
    private let now: @MainActor () -> Date
    private let makeID: @MainActor () -> UUID

    public init(
        repository: any TripRepository,
        now: @escaping @MainActor () -> Date = { Date() },
        makeID: @escaping @MainActor () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.now = now
        self.makeID = makeID
    }

    public var visibleTrips: [Trip] {
        trips.filter { trip in
            filter.matches(trip) && matchesQuery(trip)
        }
    }

    public var summaryLine: String {
        "\(count(of: .enRoute)) en route · \(count(of: .delayed)) delayed · \(count(of: .scheduled)) scheduled"
    }

    public func load() async {
        phase = .loading
        do {
            trips = try await repository.allTrips().sorted(by: Trip.boardOrder)
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    public func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
            trips.removeAll { $0.id == id }
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Returns a validation or save message. Nil means the trip is on the board.
    public func add(_ draft: NewTripDraft) async -> String? {
        guard let trip = draft.makeTrip(id: makeID(), now: now()) else {
            return draft.validationMessage ?? "Check the trip details."
        }
        do {
            try await repository.save(trip)
            trips.append(trip)
            trips.sort(by: Trip.boardOrder)
            phase = .loaded
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    public func makeDetailViewModel(
        for id: UUID,
        weather: any WeatherProviding
    ) -> TripDetailViewModel? {
        guard let trip = trips.first(where: { $0.id == id }) else { return nil }
        return TripDetailViewModel(
            trip: trip,
            repository: repository,
            weather: weather
        ) { [weak self] updated in
            self?.replace(updated)
        }
    }

    public func replace(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
        trips.sort(by: Trip.boardOrder)
    }

    private func matchesQuery(_ trip: Trip) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let haystack = [
            trip.reference,
            trip.driverName,
            trip.vehicleUnit,
            trip.origin.city,
            trip.origin.name,
            trip.destination.city,
            trip.destination.name,
            trip.cargo
        ].joined(separator: "\n").lowercased()
        return haystack.contains(needle.lowercased())
    }

    private func count(of status: TripStatus) -> Int {
        trips.filter { $0.status == status }.count
    }
}
