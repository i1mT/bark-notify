import BarkCore
import Darwin
import Foundation
import NotifySupport
import SwiftUI

struct BarkDeskApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("BarkDesk", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 980, minHeight: 640)
                .task { await model.start() }
        }
        .defaultSize(width: 1050, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("发送新通知") { model.selection = .compose }
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
    static func main() {
        let executableName = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
        if executableName == "notify" {
            let result = ExitCodeBox()
            let completion = DispatchSemaphore(value: 0)
            Task.detached {
                result.set(await NotifyRunner.run())
                completion.signal()
            }
            completion.wait()
            Darwin.exit(Int32(result.get()))
        }
        BarkDeskApp.main()
    }
}

private final class ExitCodeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 1

    func set(_ newValue: Int) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("发送新通知") {
            model.selection = .compose
            openWindow(id: "main")
        }
        Button("最近通知") {
            model.selection = .notifications
            openWindow(id: "main")
        }
        Divider()
        Button("打开 BarkDesk") { openWindow(id: "main") }
        SettingsLink { Text("设置…") }
        Divider()
        Button("退出 BarkDesk") { NSApplication.shared.terminate(nil) }
    }
}
