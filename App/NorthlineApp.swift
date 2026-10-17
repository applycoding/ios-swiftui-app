import SwiftUI
import SwiftData
import FleetLogCore

@main
struct NorthlineApp: App {
    var body: some Scene {
        WindowGroup {
            BoardHost()
        }
    }
}

private struct BoardHost: View {
    @State private var container: ModelContainer?
    @State private var failure: String?

    var body: some View {
        Group {
            if let container {
                RootView()
                    .modelContainer(container)
            } else if let failure {
                ErrorStateView(
                    title: "The board didn't open",
                    message: failure,
                    retryTitle: nil,
                    retry: nil
                )
            } else {
                LoadingStateView(
                    title: "Opening the board",
                    subtitle: "Preparing the trip store on this device."
                )
            }
        }
        .task {
            guard container == nil, failure == nil else { return }
            do {
                container = try FleetStore.makeContainer()
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}
