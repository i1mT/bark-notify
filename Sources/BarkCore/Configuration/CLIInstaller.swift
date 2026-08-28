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
    private let commonDetectionURLs: [URL]

    public init(
        installDirectory: URL? = nil,
        sourceURL: URL? = nil,
        searchPath: String = ProcessInfo.processInfo.environment["PATH"] ?? ""
    ) {
        self.installDirectory = installDirectory ?? Self.preferredInstallDirectory()
        self.sourceURL = sourceURL
        self.searchPath = searchPath
        self.commonDetectionURLs = Self.commonDetectionURLs
    }

    init(
        installDirectory: URL,
        sourceURL: URL?,
        searchPath: String,
        commonDetectionURLs: [URL]
    ) {
        self.installDirectory = installDirectory
        self.sourceURL = sourceURL
        self.searchPath = searchPath
        self.commonDetectionURLs = commonDetectionURLs
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

    private static var commonDetectionURLs: [URL] {
        [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("bin/notify"),
            URL(fileURLWithPath: "/opt/homebrew/bin/notify"),
            URL(fileURLWithPath: "/usr/local/bin/notify"),
        ]
    }

    private var detectionCandidates: [URL] {
        let fromPath = pathDirectories.map { $0.appendingPathComponent("notify") }
        var seen = Set<String>()
        return ([installURL] + commonDetectionURLs + fromPath)
            .filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private func resolvedSourceURL() -> URL? {
        let candidates = [
            sourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("notify"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("notify"),
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
            "当前 BarkDesk 构建中没有可安装的 notify 命令。"
        case .conflictingExecutable(let path):
            "\(path) 已经存在其他同名命令。请先移动它，再安装 BarkDesk CLI。"
        case .validationFailed:
            "notify 安装后未能通过可执行检查。"
        }
    }
}
