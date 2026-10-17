import Foundation

public enum LoadPhase: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

public enum TripFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case enRoute
    case delayed
    case scheduled
    case delivered

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            "All"
        case .enRoute:
            "En route"
        case .delayed:
            "Delayed"
        case .scheduled:
            "Scheduled"
        case .delivered:
            "Delivered"
        }
    }

    public func matches(_ trip: Trip) -> Bool {
        switch self {
        case .all:
            true
        case .enRoute:
            trip.status == .enRoute
        case .delayed:
            trip.status == .delayed
        case .scheduled:
            trip.status == .scheduled
        case .delivered:
            trip.status == .delivered
        }
    }
}

public struct NewTripDraft: Equatable, Sendable {
    public var reference: String
    public var driverName: String
    public var vehicleUnit: String
    public var originCity: String
    public var destinationCity: String
    public var cargo: String
    public var miles: String

    public init(
        reference: String = "",
        driverName: String = "",
        vehicleUnit: String = "",
        originCity: String = "",
        destinationCity: String = "",
        cargo: String = "",
        miles: String = ""
    ) {
        self.reference = reference
        self.driverName = driverName
        self.vehicleUnit = vehicleUnit
        self.originCity = originCity
        self.destinationCity = destinationCity
        self.cargo = cargo
        self.miles = miles
    }

    public var validationMessage: String? {
        let reference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        let driver = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = vehicleUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let cargo = cargo.trimmingCharacters(in: .whitespacesAndNewlines)
        if reference.isEmpty {
            return "Enter a trip reference."
        }
        if driver.isEmpty {
            return "Enter the driver."
        }
        if unit.isEmpty {
            return "Enter a vehicle unit."
        }
        if PlaceDirectory.city(originCity) == nil {
            return "Choose an origin city."
        }
        if PlaceDirectory.city(destinationCity) == nil {
            return "Choose a destination city."
        }
        if originCity.caseInsensitiveCompare(destinationCity) == .orderedSame {
            return "Origin and destination need to be different cities."
        }
        if cargo.isEmpty {
            return "Enter the cargo."
        }
        let milesText = miles.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let milesValue = Double(milesText), milesValue > 0 else {
            return "Enter the miles as a number greater than zero."
        }
        return nil
    }

    /// Builds a scheduled trip. Returns nil when `validationMessage` is set.
    /// ETA assumes a 55 mph line-haul average so the board has a usable time.
    public func makeTrip(id: UUID, now: Date) -> Trip? {
        guard validationMessage == nil,
              let origin = PlaceDirectory.city(originCity),
              let destination = PlaceDirectory.city(destinationCity),
              let milesValue = Double(miles.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        let hours = milesValue / 55
        return Trip(
            id: id,
            reference: reference.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            driverName: driverName.trimmingCharacters(in: .whitespacesAndNewlines),
            vehicleUnit: vehicleUnit.trimmingCharacters(in: .whitespacesAndNewlines),
            origin: origin,
            destination: destination,
            status: .scheduled,
            departure: now,
            eta: now.addingTimeInterval(hours * 3600),
            cargo: cargo.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: "",
            miles: milesValue
        )
    }
}
