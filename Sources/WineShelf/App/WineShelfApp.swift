import SwiftUI

@main
struct WineShelfApp: App {
    @StateObject private var library = LibraryModel()

    var body: some Scene {
        WindowGroup {
            LibraryView(library: library)
                .frame(minWidth: 880, minHeight: 600)
                .tint(.accentColor)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
