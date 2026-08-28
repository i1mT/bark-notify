import BarkCore
import Darwin
import Foundation

@main
enum NotifyMain {
    static func main() async {
        do {
            let command = try CLIParser.parse(Array(CommandLine.arguments.dropFirst()))
            let exitCode = try await execute(command)
            Darwin.exit(Int32(exitCode))
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            if error is CLIError { FileHandle.standardError.write(Data("Run 'notify --help' for usage.\n".utf8)) }
            Darwin.exit(1)
        }
    }

    private static func execute(_ command: CLICommand) async throws -> Int {
        switch command {
        case .help: print(help); return 0
        case .version: print("notify 1.0.0"); return 0
        case .config(let command): try await executeConfig(command); return 0
        case .history(let search, let limit): try await showHistory(search: search, limit: limit); return 0
        case .send(var options):
            if options.message == nil, options.markdown == nil, isatty(STDIN_FILENO) == 0 {
                let input = FileHandle.standardInput.readDataToEndOfFile()
                options.message = String(data: input, encoding: .utf8)?.trimmingCharacters(in: .newlines)
            }
            guard !(options.message ?? options.markdown ?? "").isEmpty else { throw CLIError.missingMessage }
            try await send(options, source: .cli)
            if !options.quiet { print("✓ Notification sent") }
            return 0
        case .run(let options, let command):
            return try await run(command, options: options)
        }
    }

    private static func send(
        _ options: SendOptions,
        source: NotificationSource,
        metadata: NotificationMetadata? = nil
    ) async throws {
        let configuration = try ConfigurationStore().load().validated()
        let request = makeRequest(options, configuration: configuration)
        let history = try HistoryStore()
        let service = NotificationService(client: BarkClient(configuration: configuration), history: history)
        try await service.send(request, source: source, metadata: metadata)
    }

    private static func makeRequest(
        _ options: SendOptions,
        configuration: ResolvedConfiguration
    ) -> BarkPushRequest {
        let settings = configuration.settings
        return BarkPushRequest(
            deviceKey: configuration.credentials.deviceKey,
            title: emptyToNil(options.title), subtitle: emptyToNil(options.subtitle),
            body: options.message ?? options.markdown ?? "", markdown: emptyToNil(options.markdown),
            level: options.level ?? settings.defaultLevel,
            volume: options.volume, badge: options.badge,
            call: options.call ? "1" : nil, autoCopy: options.autoCopy ? "1" : nil,
            copy: emptyToNil(options.copy), sound: emptyToNil(options.sound ?? settings.defaultSound),
            icon: emptyToNil(options.icon), image: emptyToNil(options.image),
            group: emptyToNil(options.group ?? settings.defaultGroup),
            isArchive: (options.archive ?? settings.archiveMessages) ? "1" : nil,
            ttl: options.ttl, url: emptyToNil(options.url),
            action: options.noAction ? "none" : nil, id: emptyToNil(options.id)
        )
    }

    private static func run(_ command: [String], options: SendOptions) async throws -> Int {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        try process.run()
        process.waitUntilExit()
        let exitCode = Int(process.terminationStatus)
        let duration = Date().timeIntervalSince(start)
        let commandText = command.map(shellQuote).joined(separator: " ")
        var notification = options
        let succeeded = process.terminationReason == .exit && exitCode == 0
        if notification.title == nil { notification.title = succeeded ? "Command completed" : "Command failed" }
        if notification.message == nil {
            let icon = succeeded ? "✅" : "❌"
            let exitLine = succeeded ? "" : "\nExit Code: \(exitCode)"
            notification.message = "\(icon) \(notification.title!)\n\n\(commandText)\(exitLine)\nDuration: \(formatDuration(duration))"
        }
        if !succeeded, notification.level == nil { notification.level = .timeSensitive }
        let metadata = NotificationMetadata(
            command: commandText,
            cwd: FileManager.default.currentDirectoryPath,
            hostname: ProcessInfo.processInfo.hostName,
            exitCode: exitCode,
            duration: duration
        )
        do {
            try await send(notification, source: .command, metadata: metadata)
            if !notification.quiet { print("✓ Command notification sent") }
        } catch {
            FileHandle.standardError.write(Data("Warning: could not send notification: \(error.localizedDescription)\n".utf8))
        }
        if process.terminationReason == .uncaughtSignal { return 128 + exitCode }
        return exitCode
    }

    private static func executeConfig(_ command: ConfigCommand) async throws {
        let store = ConfigurationStore()
        switch command {
        case .show:
            let config = try store.load()
            print("Server: \(config.settings.serverURL.isEmpty ? "Not configured" : config.settings.serverURL)")
            print("Device: \(masked(config.credentials.deviceKey))")
            print("Authentication: \(config.settings.authenticationMode.rawValue)")
            print("Group: \(config.settings.defaultGroup)")
            print("Level: \(config.settings.defaultLevel.rawValue)")
            print("Sound: \(config.settings.defaultSound.isEmpty ? "default" : config.settings.defaultSound)")
            print("Archive: \(config.settings.archiveMessages ? "yes" : "no")")
        case .test:
            let config = try store.load().validated()
            let client = BarkClient(configuration: config)
            try await client.ping()
            print("✓ Server reachable")
            do { _ = try await client.info(); print("✓ Server info available") }
            catch { print("! Server info unavailable: \(error.localizedDescription)") }
            do { _ = try await client.checkDevice(deviceKey: config.credentials.deviceKey); print("✓ Device registered") }
            catch { print("! Device check unavailable: \(error.localizedDescription)") }
        case .set(let updates):
            let current = try store.load()
            var settings = current.settings
            var credentials = current.credentials
            if let value = updates.server { settings.serverURL = value }
            if let value = updates.group { settings.defaultGroup = value }
            if let value = updates.level { settings.defaultLevel = value }
            if let value = updates.sound { settings.defaultSound = value }
            if let value = updates.archive { settings.archiveMessages = value }
            if let value = updates.device { credentials.deviceKey = value }
            if let value = updates.username { credentials.username = value; settings.authenticationMode = .basic }
            if let value = updates.password { credentials.password = value; settings.authenticationMode = .basic }
            if updates.noAuth {
                settings.authenticationMode = .none
                credentials.username = ""
                credentials.password = ""
            }
            try store.save(ResolvedConfiguration(settings: settings, credentials: credentials))
            print("✓ Configuration saved")
        }
    }

    private static func showHistory(search: String?, limit: Int) async throws {
        let records = try await HistoryStore().records(search: search, limit: limit)
        if records.isEmpty { print("No notification history."); return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        for record in records {
            let status = record.deliveryStatus == .success ? "✓" : "✗"
            let heading = record.title.flatMap(emptyToNil) ?? record.body.components(separatedBy: .newlines).first ?? "Notification"
            print("\(status) \(formatter.string(from: record.createdAt))  \(heading)  [\(record.source.rawValue)]")
        }
    }

    private static func emptyToNil(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func masked(_ value: String) -> String {
        guard !value.isEmpty else { return "Not configured" }
        return "••••\(value.suffix(4))"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total >= 3600 { return "\(total / 3600)h \((total % 3600) / 60)m \(total % 60)s" }
        if total >= 60 { return "\(total / 60)m \(total % 60)s" }
        return "\(max(0, total))s"
    }

    private static func shellQuote(_ value: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_./-"))
        if value.unicodeScalars.allSatisfy({ safe.contains($0) }) { return value }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static let help = """
    notify — send Bark notifications without long commands

    USAGE
      notify "Message"
      echo "Message" | notify -t "Title"
      notify run [notification options] -- command [arguments]
      notify config show|test|set [options]
      notify history [--search text] [--limit number]

    COMMON OPTIONS
      -m, --message TEXT       Notification body
      -t, --title TEXT         Title
      -s, --subtitle TEXT      Subtitle
      -g, --group TEXT         Group
          --level LEVEL        active, timeSensitive, passive, critical
          --sound NAME         Bark sound
          --icon URL           Custom icon
          --image URL          Image attachment
          --url URL            Open URL when tapped
          --markdown TEXT      Markdown body (requires a recent Bark Server)
          --volume 0...10      Critical alert volume
          --badge NUMBER       App badge
          --call               Repeat ringtone
          --auto-copy          Enable automatic copy
          --copy TEXT          Copy action text
          --archive            Archive in Bark
          --no-archive         Do not archive in Bark
          --ttl SECONDS        Archived-message lifetime
          --no-action          Tapping performs no action
      -q, --quiet              No success output

    CONFIGURATION
      notify config set --server URL --device KEY
      notify config set --username USER --password PASS
      notify config set --group terminal --level active --archive
    """
}
