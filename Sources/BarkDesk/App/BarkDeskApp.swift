import BarkCore
import SwiftUI

@main
struct BarkDeskApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("BarkDesk", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 880, minHeight: 600)
                .task { await model.start() }
        }
        .defaultSize(width: 1050, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Notification") { model.selection = .compose }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }

        MenuBarExtra("BarkDesk", systemImage: "bell.badge") {
            MenuBarView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 560, height: 620)
        }
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Notification") {
            model.selection = .compose
            openWindow(id: "main")
        }
        Button("Recent Notifications") {
            model.selection = .notifications
            openWindow(id: "main")
        }
        Divider()
        Button("Open BarkDesk") { openWindow(id: "main") }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit BarkDesk") { NSApplication.shared.terminate(nil) }
    }
}
