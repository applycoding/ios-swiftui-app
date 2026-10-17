import Foundation
import Observation

@MainActor
@Observable
public final class TripDetailViewModel {
    public private(set) var trip: Trip
    public var notes: String
    public private(set) var weather: DestinationWeather?
    public private(set) var weatherPhase: LoadPhase = .idle
    public private(set) var actionError: String?

    private let repository: any TripRepository
    private let weatherClient: any WeatherProviding
    private let onChange: @MainActor (Trip) -> Void
    private var weatherRequest = 0

    public init(
        trip: Trip,
        repository: any TripRepository,
        weather: any WeatherProviding,
        onChange: @escaping @MainActor (Trip) -> Void = { _ in }
    ) {
        self.trip = trip
        self.notes = trip.notes
        self.repository = repository
        self.weatherClient = weather
        self.onChange = onChange
    }

    public var hasUnsavedNotes: Bool {
        notes != trip.notes
    }

    public func loadWeather() async {
        weatherRequest += 1
        let request = weatherRequest
        weather = nil
        weatherPhase = .loading
        do {
            let forecast = try await weatherClient.forecast(for: trip.destination)
            guard request == weatherRequest else { return }
            weather = forecast
            weatherPhase = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard request == weatherRequest else { return }
            weather = nil
            weatherPhase = .failed(error.localizedDescription)
        }
    }

    public func saveNotes() async {
        var updated = trip
        updated.notes = notes
        await persist(updated)
    }

    public func setStatus(_ status: TripStatus) async {
        guard status != trip.status else { return }
        var updated = trip
        updated.status = status
        await persist(updated)
    }

    private func persist(_ updated: Trip) async {
        do {
            try await repository.save(updated)
            trip = updated
            notes = updated.notes
            actionError = nil
            onChange(updated)
        } catch {
            actionError = error.localizedDescription
        }
    }
}
