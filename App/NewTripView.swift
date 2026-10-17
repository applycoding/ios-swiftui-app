import SwiftUI
import FleetLogCore

struct NewTripView: View {
    let model: TripListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = NewTripDraft()
    @State private var didAttempt = false
    @State private var message: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Reference", text: $draft.reference)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Driver", text: $draft.driverName)
                        .textInputAutocapitalization(.words)
                    TextField("Vehicle unit", text: $draft.vehicleUnit)
                }
                Section("Lane") {
                    Picker("Origin", selection: $draft.originCity) {
                        Text("Select a city").tag("")
                        ForEach(PlaceDirectory.all) { place in
                            Text(place.label).tag(place.city)
                        }
                    }
                    Picker("Destination", selection: $draft.destinationCity) {
                        Text("Select a city").tag("")
                        ForEach(PlaceDirectory.all) { place in
                            Text(place.label).tag(place.city)
                        }
                    }
                }
                Section("Load") {
                    TextField("Cargo", text: $draft.cargo)
                    TextField("Miles", text: $draft.miles)
                        .keyboardType(.decimalPad)
                }
                if let shownMessage {
                    Section {
                        Text(shownMessage)
                            .font(.footnote)
                            .foregroundStyle(FleetTheme.amber)
                    }
                }
            }
            .navigationTitle("New trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private var shownMessage: String? {
        if let message { return message }
        if didAttempt { return draft.validationMessage }
        return nil
    }

    private func save() async {
        didAttempt = true
        message = nil
        guard draft.validationMessage == nil else { return }
        isSaving = true
        let result = await model.add(draft)
        isSaving = false
        if let result {
            message = result
        } else {
            dismiss()
        }
    }
}
