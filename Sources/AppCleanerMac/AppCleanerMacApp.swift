import SwiftUI

struct AppCleanerMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
