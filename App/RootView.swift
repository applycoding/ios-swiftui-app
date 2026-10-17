import SwiftUI
import SwiftData
import FleetLogCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var listModel: TripListViewModel?
    @State private var weather: (any WeatherProviding)?
    @State private var failure: String?
    @State private var attempt = 0

    var body: some View {
        Group {
            if let listModel, let weather {
                TripListView(model: listModel, weather: weather)
            } else if let failure {
                ErrorStateView(
                    title: "The trips didn't load",
                    message: failure,
                    retry: retry
                )
            } else {
                LoadingStateView(
                    title: "Checking the board",
                    subtitle: "Loading trips saved on this device."
                )
            }
        }
        .background(FleetTheme.paper.ignoresSafeArea())
        .task(id: attempt) {
            await openBoard()
        }
    }

    private func retry() {
        failure = nil
        listModel = nil
        weather = nil
        attempt += 1
    }

    private func openBoard() async {
        guard listModel == nil, failure == nil else { return }
        let repository = SwiftDataTripRepository(context: modelContext)
        let client = OpenMeteoWeatherProvider(
            client: URLSessionHTTPClient(session: makeSession()),
            fallback: MockWeatherProvider()
        )
        let model = TripListViewModel(repository: repository)
        do {
            try await repository.seedIfEmpty(SeedData.trips())
            weather = client
            listModel = model
            await model.load()
        } catch {
            failure = error.localizedDescription
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}
