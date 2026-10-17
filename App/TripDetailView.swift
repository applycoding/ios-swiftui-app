import SwiftUI
import FleetLogCore

struct TripDetailContainer: View {
    let tripID: UUID
    var listModel: TripListViewModel
    let weather: any WeatherProviding
    @State private var detail: TripDetailViewModel?

    var body: some View {
        Group {
            if let detail {
                TripDetailView(model: detail)
            } else if listModel.trips.contains(where: { $0.id == tripID }) {
                LoadingStateView(
                    title: "Opening the trip",
                    subtitle: "Loading the stop and destination weather."
                )
            } else {
                ErrorStateView(
                    title: "That trip left the board",
                    message: "It is no longer saved on this device.",
                    retryTitle: nil,
                    retry: nil
                )
            }
        }
        .background(FleetTheme.paper)
        .task(id: tripID) {
            guard detail == nil else { return }
            detail = listModel.makeDetailViewModel(for: tripID, weather: weather)
            await detail?.loadWeather()
        }
    }
}

struct TripDetailView: View {
    @Bindable var model: TripDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                weatherSection
                facts
                notes
                statusControls
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(FleetTheme.paper)
        .navigationTitle(model.trip.reference)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.trip.reference)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(FleetTheme.inkSoft)
                Spacer()
                StatusBadge(status: model.trip.status)
            }
            Text(model.trip.routeTitle)
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(FleetTheme.ink)
            Text("\(model.trip.origin.name) to \(model.trip.destination.name)")
                .font(.subheadline)
                .foregroundStyle(FleetTheme.inkSoft)
        }
    }

    @ViewBuilder
    private var weatherSection: some View {
        switch model.weatherPhase {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Checking destination weather")
                    .font(.subheadline)
                    .foregroundStyle(FleetTheme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(FleetTheme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FleetTheme.line, lineWidth: 1))
        case .loaded:
            if let weather = model.weather {
                WeatherCard(weather: weather)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Weather unavailable")
                    .font(.headline)
                    .foregroundStyle(FleetTheme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(FleetTheme.inkSoft)
                Button("Retry") {
                    Task { await model.loadWeather() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(FleetTheme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FleetTheme.line, lineWidth: 1))
        }
    }

    private var facts: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
            FactBlock(title: "Driver", value: model.trip.driverName)
            FactBlock(title: "Unit", value: model.trip.vehicleUnit)
            FactBlock(title: "Departure", value: FleetFormat.stamp(model.trip.departure))
            FactBlock(title: "ETA", value: FleetFormat.stamp(model.trip.eta))
            FactBlock(title: "Miles", value: FleetFormat.miles(model.trip.miles))
            FactBlock(title: "Cargo", value: model.trip.cargo)
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Notes")
            TextEditor(text: $model.notes)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(FleetTheme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(FleetTheme.line, lineWidth: 1))
                .font(.body)
                .foregroundStyle(FleetTheme.ink)
            HStack {
                if let actionError = model.actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(FleetTheme.amber)
                }
                Spacer()
                Button("Save note") {
                    Task { await model.saveNotes() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.hasUnsavedNotes)
            }
        }
    }

    private var statusControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Status")
            HStack(spacing: 8) {
                ForEach(TripStatus.allCases) { status in
                    Button {
                        Task { await model.setStatus(status) }
                    } label: {
                        Text(status.title)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.trip.status == status ? FleetTheme.color(for: status) : FleetTheme.inkSoft)
                    .disabled(model.trip.status == status)
                }
            }
        }
    }
}

private struct WeatherCard: View {
    let weather: DestinationWeather

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(FleetFormat.temperature(weather.temperatureFahrenheit))
                    .font(.system(size: 44, weight: .regular, design: .serif))
                    .foregroundStyle(FleetTheme.ink)
                Spacer()
                Text(weather.condition)
                    .font(.headline)
                    .foregroundStyle(FleetTheme.ink)
                    .multilineTextAlignment(.trailing)
            }
            Text(FleetFormat.wind(weather.windMilesPerHour))
                .font(.subheadline)
                .foregroundStyle(FleetTheme.inkSoft)
            Text(sourceLine)
                .font(.footnote)
                .foregroundStyle(FleetTheme.inkSoft)
            if weather.source == .live, !weather.observedAt.isEmpty {
                Text("Observed \(weather.observedAt)")
                    .font(.footnote)
                    .foregroundStyle(FleetTheme.inkSoft)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FleetTheme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var sourceLine: String {
        switch weather.source {
        case .live:
            "Live from Open-Meteo"
        case .sample:
            "Sample forecast — Open-Meteo was unreachable"
        }
    }
}
