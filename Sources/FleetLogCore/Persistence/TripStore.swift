import Foundation
import SwiftData

@MainActor
public protocol TripRepository: AnyObject {
    func allTrips() async throws -> [Trip]
    func save(_ trip: Trip) async throws
    func delete(id: UUID) async throws
    func seedIfEmpty(_ trips: [Trip]) async throws
}

public enum TripStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidDraft(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDraft(let message):
            message
        case .saveFailed(let message):
            message
        }
    }
}

public enum FleetStore {
    @MainActor
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let name = inMemory ? "Northline-Memory-\(UUID().uuidString)" : "Northline"
        let configuration = ModelConfiguration(
            name,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: TripRecord.self, configurations: configuration)
    }
}

@MainActor
public final class SwiftDataTripRepository: TripRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
        context.autosaveEnabled = false
    }

    public func allTrips() async throws -> [Trip] {
        do {
            let records = try context.fetch(FetchDescriptor<TripRecord>())
            return records.map { $0.trip() }
        } catch {
            throw TripStoreError.saveFailed(error.localizedDescription)
        }
    }

    public func save(_ trip: Trip) async throws {
        do {
            let records = try context.fetch(FetchDescriptor<TripRecord>())
            if let record = records.first(where: { $0.id == trip.id }) {
                record.apply(trip)
            } else {
                context.insert(TripRecord(trip: trip))
            }
            try context.save()
        } catch {
            throw TripStoreError.saveFailed(error.localizedDescription)
        }
    }

    public func delete(id: UUID) async throws {
        do {
            let records = try context.fetch(FetchDescriptor<TripRecord>())
            guard let record = records.first(where: { $0.id == id }) else { return }
            context.delete(record)
            try context.save()
        } catch {
            throw TripStoreError.saveFailed(error.localizedDescription)
        }
    }

    public func seedIfEmpty(_ trips: [Trip]) async throws {
        do {
            let existing = try context.fetch(FetchDescriptor<TripRecord>())
            guard existing.isEmpty else { return }
            for trip in trips {
                context.insert(TripRecord(trip: trip))
            }
            try context.save()
        } catch {
            throw TripStoreError.saveFailed(error.localizedDescription)
        }
    }
}

@MainActor
public final class InMemoryTripRepository: TripRepository {
    public var trips: [Trip]
    public var error: TripStoreError?

    public init(trips: [Trip] = []) {
        self.trips = trips
    }

    public func allTrips() async throws -> [Trip] {
        if let error { throw error }
        return trips
    }

    public func save(_ trip: Trip) async throws {
        if let error { throw error }
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
        } else {
            trips.append(trip)
        }
    }

    public func delete(id: UUID) async throws {
        if let error { throw error }
        trips.removeAll { $0.id == id }
    }

    public func seedIfEmpty(_ seed: [Trip]) async throws {
        if let error { throw error }
        guard trips.isEmpty else { return }
        trips = seed
    }
}

@Model
final class TripRecord {
    var id: UUID = UUID()
    var reference: String = ""
    var driverName: String = ""
    var vehicleUnit: String = ""
    var originName: String = ""
    var originCity: String = ""
    var originRegion: String = ""
    var originLatitude: Double = 0
    var originLongitude: Double = 0
    var destinationName: String = ""
    var destinationCity: String = ""
    var destinationRegion: String = ""
    var destinationLatitude: Double = 0
    var destinationLongitude: Double = 0
    var statusRaw: String = TripStatus.scheduled.rawValue
    var departure: Date = .now
    var eta: Date = .now
    var cargo: String = ""
    var notes: String = ""
    var miles: Double = 0

    init(trip: Trip) {
        id = trip.id
        reference = trip.reference
        driverName = trip.driverName
        vehicleUnit = trip.vehicleUnit
        originName = trip.origin.name
        originCity = trip.origin.city
        originRegion = trip.origin.region
        originLatitude = trip.origin.latitude
        originLongitude = trip.origin.longitude
        destinationName = trip.destination.name
        destinationCity = trip.destination.city
        destinationRegion = trip.destination.region
        destinationLatitude = trip.destination.latitude
        destinationLongitude = trip.destination.longitude
        statusRaw = trip.status.rawValue
        departure = trip.departure
        eta = trip.eta
        cargo = trip.cargo
        notes = trip.notes
        miles = trip.miles
    }

    func apply(_ trip: Trip) {
        reference = trip.reference
        driverName = trip.driverName
        vehicleUnit = trip.vehicleUnit
        originName = trip.origin.name
        originCity = trip.origin.city
        originRegion = trip.origin.region
        originLatitude = trip.origin.latitude
        originLongitude = trip.origin.longitude
        destinationName = trip.destination.name
        destinationCity = trip.destination.city
        destinationRegion = trip.destination.region
        destinationLatitude = trip.destination.latitude
        destinationLongitude = trip.destination.longitude
        statusRaw = trip.status.rawValue
        departure = trip.departure
        eta = trip.eta
        cargo = trip.cargo
        notes = trip.notes
        miles = trip.miles
    }

    func trip() -> Trip {
        Trip(
            id: id,
            reference: reference,
            driverName: driverName,
            vehicleUnit: vehicleUnit,
            origin: Place(
                name: originName,
                city: originCity,
                region: originRegion,
                latitude: originLatitude,
                longitude: originLongitude
            ),
            destination: Place(
                name: destinationName,
                city: destinationCity,
                region: destinationRegion,
                latitude: destinationLatitude,
                longitude: destinationLongitude
            ),
            status: TripStatus(rawValue: statusRaw) ?? .scheduled,
            departure: departure,
            eta: eta,
            cargo: cargo,
            notes: notes,
            miles: miles
        )
    }
}
