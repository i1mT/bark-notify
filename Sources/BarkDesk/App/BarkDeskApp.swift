import BarkCore
import Darwin
import NotifySupport
import SwiftUI

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

@main
enum BarkDeskMain {
    @MainActor
    static func main() async {
        let executableName = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
        if executableName == "notify" {
            Darwin.exit(Int32(await NotifyRunner.run()))
        }
        BarkDeskApp.main()
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
