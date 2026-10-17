import Foundation

public enum SeedData {
    public static func trips(now: Date = Date()) -> [Trip] {
        let hour: TimeInterval = 3600
        return [
            Trip(
                id: seedID(1),
                reference: "NL-1042",
                driverName: "Amina Okonkwo",
                vehicleUnit: "418",
                origin: PlaceDirectory.tacoma,
                destination: PlaceDirectory.saltLakeCity,
                status: .enRoute,
                departure: now.addingTimeInterval(-3 * hour),
                eta: now.addingTimeInterval(8 * hour),
                cargo: "Medical imaging kits",
                notes: "Seal checked at the port gate. Receiver wants a call one hour out.",
                miles: 812
            ),
            Trip(
                id: seedID(2),
                reference: "NL-1108",
                driverName: "Luis Herrera",
                vehicleUnit: "227",
                origin: PlaceDirectory.everett,
                destination: PlaceDirectory.denver,
                status: .delayed,
                departure: now.addingTimeInterval(-5 * hour),
                eta: now.addingTimeInterval(16 * hour),
                cargo: "Kiln-dried lumber",
                notes: "Holding at Ellensburg for a chain check. Wind advisory on the pass.",
                miles: 1324
            ),
            Trip(
                id: seedID(3),
                reference: "NL-0988",
                driverName: "Priya Shah",
                vehicleUnit: "156",
                origin: PlaceDirectory.portland,
                destination: PlaceDirectory.spokane,
                status: .enRoute,
                departure: now.addingTimeInterval(-1 * hour),
                eta: now.addingTimeInterval(5 * hour),
                cargo: "CNC machine parts",
                notes: "No stack. Dock appointment is firm.",
                miles: 350
            ),
            Trip(
                id: seedID(4),
                reference: "NL-1215",
                driverName: "Evan Brooks",
                vehicleUnit: "512",
                origin: PlaceDirectory.seattle,
                destination: PlaceDirectory.boise,
                status: .scheduled,
                departure: now.addingTimeInterval(2 * hour),
                eta: now.addingTimeInterval(11 * hour),
                cargo: "Refrigerated produce",
                notes: "Set point 34°F. Pre-cool before the Sodo hook.",
                miles: 494
            ),
            Trip(
                id: seedID(5),
                reference: "NL-0874",
                driverName: "Nora Chen",
                vehicleUnit: "303",
                origin: PlaceDirectory.oakland,
                destination: PlaceDirectory.reno,
                status: .scheduled,
                departure: now.addingTimeInterval(6 * hour),
                eta: now.addingTimeInterval(11 * hour),
                cargo: "Bookstore returns",
                notes: "",
                miles: 218
            ),
            Trip(
                id: seedID(6),
                reference: "NL-0761",
                driverName: "Malik Wright",
                vehicleUnit: "640",
                origin: PlaceDirectory.medford,
                destination: PlaceDirectory.sacramento,
                status: .delivered,
                departure: now.addingTimeInterval(-20 * hour),
                eta: now.addingTimeInterval(-8 * hour),
                cargo: "Clinic resupply",
                notes: "Received by dock 4. POD is in the cab folder.",
                miles: 338
            )
        ]
    }

    private static func seedID(_ suffix: Int) -> UUID {
        let value = String(format: "10000000-0000-0000-0000-%012d", suffix)
        guard let id = UUID(uuidString: value) else {
            preconditionFailure("Seed identifier \(value) is not a UUID.")
        }
        return id
    }
}
