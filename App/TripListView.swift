import SwiftUI
import FleetLogCore

struct TripListView: View {
    @Bindable var model: TripListViewModel
    let weather: any WeatherProviding
    @State private var showingComposer = false

    var body: some View {
        NavigationStack {
            board
                .navigationTitle("Northline")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingComposer = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("New trip")
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    TripDetailContainer(tripID: id, listModel: model, weather: weather)
                }
                .searchable(text: $model.query, prompt: "Driver, city, or reference")
                .refreshable {
                    await model.load()
                }
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FleetTheme.paper)
        .tint(FleetTheme.pine)
        .sheet(isPresented: $showingComposer) {
            NewTripView(model: model)
        }
    }

    @ViewBuilder
    private var board: some View {
        switch model.phase {
        case .idle, .loading:
            if model.trips.isEmpty {
                LoadingStateView(
                    title: "Checking the board",
                    subtitle: "Loading trips saved on this device."
                )
            } else {
                tripList
            }
        case .failed(let message):
            if model.trips.isEmpty {
                ErrorStateView(title: "The board didn't load", message: message) {
                    Task { await model.load() }
                }
            } else {
                tripList(banner: message)
            }
        case .loaded:
            if model.trips.isEmpty {
                emptyBoard(
                    title: "The board is clear",
                    message: "New trips you add are saved on this device."
                )
            } else if model.visibleTrips.isEmpty {
                emptyBoard(
                    title: "Nothing matches",
                    message: "Try another driver, city, reference, or filter."
                )
            } else {
                tripList
            }
        }
    }

    private func tripList(banner: String? = nil) -> some View {
        List {
            Section {
                header
                if let banner {
                    bannerRow(banner)
                }
                filterRow
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(FleetTheme.paper)

            Section {
                ForEach(model.visibleTrips) { trip in
                    NavigationLink(value: trip.id) {
                        TripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await model.delete(id: trip.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(FleetTheme.paper)
                }
            }

            Section {
                Text("Sample trips stay on this device. Destination weather comes from Open-Meteo and falls back to a saved forecast when the request fails.")
                    .font(.footnote)
                    .foregroundStyle(FleetTheme.inkSoft)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 24, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(FleetTheme.paper)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(FleetTheme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dispatch board")
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(FleetTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(model.summaryLine)
                .font(.subheadline)
                .foregroundStyle(FleetTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TripFilter.allCases) { filter in
                    let selected = model.filter == filter
                    Button {
                        model.filter = filter
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(selected ? FleetTheme.paper : FleetTheme.ink)
                            .background(selected ? FleetTheme.ink : FleetTheme.card, in: Capsule())
                            .overlay(Capsule().stroke(selected ? Color.clear : FleetTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
                }
            }
        }
        .frame(height: 44)
    }

    private func bannerRow(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(FleetTheme.ink)
            Spacer(minLength: 12)
            Button("Retry") {
                Task { await model.load() }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(FleetTheme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func emptyBoard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            filterRow
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(FleetTheme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(FleetTheme.inkSoft)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FleetTheme.paper)
    }
}

private struct TripCard: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(trip.reference)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(FleetTheme.ink)
                Spacer(minLength: 8)
                StatusBadge(status: trip.status)
            }
            Text(trip.routeTitle)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(FleetTheme.ink)
            Text("\(trip.driverName) · Unit \(trip.vehicleUnit)")
                .font(.subheadline)
                .foregroundStyle(FleetTheme.inkSoft)
            HStack(alignment: .firstTextBaseline) {
                Text(trip.cargo)
                Text("·")
                Text(FleetFormat.miles(trip.miles))
                Spacer(minLength: 8)
                Text(FleetFormat.stamp(trip.eta))
            }
            .font(.footnote)
            .foregroundStyle(FleetTheme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FleetTheme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(FleetTheme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
