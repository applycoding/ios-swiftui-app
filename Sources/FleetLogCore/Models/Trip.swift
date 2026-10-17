import Foundation

public struct Place: Identifiable, Equatable, Hashable, Sendable {
    public var name: String
    public var city: String
    public var region: String
    public var latitude: Double
    public var longitude: Double

    public var id: String { city }

    public var label: String { "\(city), \(region)" }

    public init(name: String, city: String, region: String, latitude: Double, longitude: Double) {
        self.name = name
        self.city = city
        self.region = region
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum PlaceDirectory {
    public static let boise = Place(name: "Gowen Spur", city: "Boise", region: "ID", latitude: 43.6150, longitude: -116.2023)
    public static let denver = Place(name: "Montbello Dock", city: "Denver", region: "CO", latitude: 39.7392, longitude: -104.9903)
    public static let everett = Place(name: "Riverside Yard", city: "Everett", region: "WA", latitude: 47.9790, longitude: -122.2021)
    public static let medford = Place(name: "Northgate Yard", city: "Medford", region: "OR", latitude: 42.3265, longitude: -122.8756)
    public static let oakland = Place(name: "Middle Harbor", city: "Oakland", region: "CA", latitude: 37.8044, longitude: -122.2712)
    public static let portland = Place(name: "Swan Island", city: "Portland", region: "OR", latitude: 45.5152, longitude: -122.6784)
    public static let reno = Place(name: "Sparks Crossdock", city: "Reno", region: "NV", latitude: 39.5296, longitude: -119.8138)
    public static let sacramento = Place(name: "Del Paso Yard", city: "Sacramento", region: "CA", latitude: 38.5816, longitude: -121.4944)
    public static let saltLakeCity = Place(name: "International Center", city: "Salt Lake City", region: "UT", latitude: 40.7608, longitude: -111.8910)
    public static let seattle = Place(name: "Sodo Dock", city: "Seattle", region: "WA", latitude: 47.6062, longitude: -122.3321)
    public static let spokane = Place(name: "Geiger Spur", city: "Spokane", region: "WA", latitude: 47.6588, longitude: -117.4260)
    public static let tacoma = Place(name: "Port of Tacoma", city: "Tacoma", region: "WA", latitude: 47.2529, longitude: -122.4443)

    public static let all: [Place] = [
        boise, denver, everett, medford, oakland, portland, reno, sacramento, saltLakeCity, seattle, spokane, tacoma
    ]

    public static func city(_ name: String) -> Place? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        return all.first { $0.city.caseInsensitiveCompare(needle) == .orderedSame }
    }
}

public enum TripStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case scheduled
    case enRoute
    case delayed
    case delivered

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scheduled:
            "Scheduled"
        case .enRoute:
            "En route"
        case .delayed:
            "Delayed"
        case .delivered:
            "Delivered"
        }
    }

    /// Delayed work sits at the top of the board, finished work at the bottom.
    public var sortRank: Int {
        switch self {
        case .delayed:
            0
        case .enRoute:
            1
        case .scheduled:
            2
        case .delivered:
            3
        }
    }
}

public struct Trip: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var reference: String
    public var driverName: String
    public var vehicleUnit: String
    public var origin: Place
    public var destination: Place
    public var status: TripStatus
    public var departure: Date
    public var eta: Date
    public var cargo: String
    public var notes: String
    public var miles: Double

    public init(
        id: UUID,
        reference: String,
        driverName: String,
        vehicleUnit: String,
        origin: Place,
        destination: Place,
        status: TripStatus,
        departure: Date,
        eta: Date,
        cargo: String,
        notes: String,
        miles: Double
    ) {
        self.id = id
        self.reference = reference
        self.driverName = driverName
        self.vehicleUnit = vehicleUnit
        self.origin = origin
        self.destination = destination
        self.status = status
        self.departure = departure
        self.eta = eta
        self.cargo = cargo
        self.notes = notes
        self.miles = miles
    }

    public var routeTitle: String {
        "\(origin.city) → \(destination.city)"
    }

    public static func boardOrder(_ lhs: Trip, _ rhs: Trip) -> Bool {
        if lhs.status.sortRank != rhs.status.sortRank {
            return lhs.status.sortRank < rhs.status.sortRank
        }
        if lhs.eta != rhs.eta {
            return lhs.eta < rhs.eta
        }
        return lhs.reference < rhs.reference
    }
}
