import Foundation

public enum CLIInstallationStatus: Equatable, Sendable {
    case checking
    case missing
    case installed(URL)
    case unavailable(String)

    public var installedURL: URL? {
        if case .installed(let url) = self { return url }
        return nil
    }
}

public struct CLIInstaller: Sendable {
    public let installDirectory: URL
    private let sourceURL: URL?
    private let searchPath: String

    public init(
        installDirectory: URL? = nil,
        sourceURL: URL? = nil,
        searchPath: String = ProcessInfo.processInfo.environment["PATH"] ?? ""
    ) {
        self.installDirectory = installDirectory ?? Self.preferredInstallDirectory()
        self.sourceURL = sourceURL
        self.searchPath = searchPath
    }

    public var installURL: URL {
        installDirectory.appendingPathComponent("notify")
    }

    public var installDirectoryIsInPath: Bool {
        pathDirectories.contains { $0.standardizedFileURL == installDirectory.standardizedFileURL }
    }

    public func detect() -> CLIInstallationStatus {
        for candidate in detectionCandidates where isBarkDeskCLI(candidate) {
            return .installed(candidate.resolvingSymlinksInPath())
        }
        return .missing
    }

    public func install() throws -> URL {
        if isBarkDeskCLI(installURL) { return installURL }
        if FileManager.default.fileExists(atPath: installURL.path) {
            throw CLIInstallerError.conflictingExecutable(path: installURL.path)
        }
        guard let source = resolvedSourceURL() else {
            throw CLIInstallerError.sourceUnavailable
        }
        try FileManager.default.createDirectory(
            at: installDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        let temporary = installDirectory.appendingPathComponent(".notify-install-\(UUID().uuidString)")
        do {
            try FileManager.default.copyItem(at: source, to: temporary)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
            try FileManager.default.moveItem(at: temporary, to: installURL)
            guard isBarkDeskCLI(installURL) else {
                try? FileManager.default.removeItem(at: installURL)
                throw CLIInstallerError.validationFailed
            }
            return installURL
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private var pathDirectories: [URL] {
        searchPath.split(separator: ":").map { URL(fileURLWithPath: String($0), isDirectory: true) }
    }

    private static func preferredInstallDirectory() -> URL {
        let fileManager = FileManager.default
        for path in ["/opt/homebrew/bin", "/usr/local/bin"]
        where fileManager.fileExists(atPath: path) && fileManager.isWritableFile(atPath: path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin", isDirectory: true)
    }

    private var detectionCandidates: [URL] {
        let common = [
            installURL,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/notify"),
            URL(fileURLWithPath: "/opt/homebrew/bin/notify"),
            URL(fileURLWithPath: "/usr/local/bin/notify"),
        ]
        let fromPath = pathDirectories.map { $0.appendingPathComponent("notify") }
        var seen = Set<String>()
        return (common + fromPath).filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private func resolvedSourceURL() -> URL? {
        let executable = Bundle.main.executableURL
        let candidates = [
            sourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("notify"),
            executable?.deletingLastPathComponent().appendingPathComponent("notify"),
            executable,
        ].compactMap { $0 }
        return candidates.first { url in
            FileManager.default.isExecutableFile(atPath: url.path) && url.standardizedFileURL != installURL.standardizedFileURL
        }
    }

    private func isBarkDeskCLI(_ url: URL) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: url.path) else { return false }
        let process = Process()
        let output = Pipe()
        process.executableURL = url
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = Pipe()
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }
        do {
            try process.run()
            guard completion.wait(timeout: .now() + 2) == .success else {
                process.terminate()
                return false
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return process.terminationStatus == 0
                && String(data: data, encoding: .utf8)?.hasPrefix("notify ") == true
        } catch {
            return false
        }
    }
}

public enum CLIInstallerError: LocalizedError {
    case sourceUnavailable
    case conflictingExecutable(path: String)
    case validationFailed

    public var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            "The notify executable is not available in this BarkDesk build."
        case .conflictingExecutable(let path):
            "Another executable already exists at \(path). Move it before installing BarkDesk CLI."
        case .validationFailed:
            "The installed notify executable could not be validated."
        }
    }
}
