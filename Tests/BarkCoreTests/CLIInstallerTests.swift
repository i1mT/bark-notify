import Foundation
import Testing
@testable import BarkCore

@Test("CLI installer detects and installs the bundled executable")
func cliInstallerLifecycle() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let source = root.appendingPathComponent("source-notify")
    try Data("#!/bin/sh\necho 'notify 1.0.0'\n".utf8).write(to: source)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)

    let installDirectory = root.appendingPathComponent("bin", isDirectory: true)
    let installer = CLIInstaller(
        installDirectory: installDirectory,
        sourceURL: source,
        searchPath: ""
    )
    #expect(installer.detect() == .missing)

    let installedURL = try installer.install()
    #expect(installedURL == installDirectory.appendingPathComponent("notify"))
    #expect(installer.detect() == .installed(installedURL))
    #expect(FileManager.default.isExecutableFile(atPath: installedURL.path))
}

@Test("CLI installer never overwrites an unrelated executable")
func cliInstallerProtectsExistingCommand() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let installDirectory = root.appendingPathComponent("bin", isDirectory: true)
    try FileManager.default.createDirectory(at: installDirectory, withIntermediateDirectories: true)
    let target = installDirectory.appendingPathComponent("notify")
    try Data("#!/bin/sh\necho 'another tool'\n".utf8).write(to: target)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)

    let installer = CLIInstaller(installDirectory: installDirectory, sourceURL: target, searchPath: "")
    #expect(throws: CLIInstallerError.self) { try installer.install() }
    #expect(try String(contentsOf: target, encoding: .utf8).contains("another tool"))
}
