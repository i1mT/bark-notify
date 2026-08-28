import BarkCore
import Foundation

struct SendOptions {
    var message: String?
    var title: String?
    var subtitle: String?
    var markdown: String?
    var group: String?
    var level: BarkLevel?
    var sound: String?
    var icon: String?
    var image: String?
    var url: String?
    var copy: String?
    var volume: Int?
    var badge: Int?
    var ttl: Int?
    var call = false
    var autoCopy = false
    var archive: Bool?
    var noAction = false
    var id: String?
    var quiet = false
}

enum CLICommand {
    case send(SendOptions)
    case run(options: SendOptions, command: [String])
    case config(ConfigCommand)
    case history(search: String?, limit: Int)
    case help
    case version
}

enum ConfigCommand {
    case show
    case test
    case set(ConfigUpdates)
}

struct ConfigUpdates {
    var server: String?
    var device: String?
    var group: String?
    var level: BarkLevel?
    var sound: String?
    var archive: Bool?
    var username: String?
    var password: String?
    var noAuth = false
}

enum CLIParser {
    static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let first = arguments.first else { return .send(SendOptions()) }
        switch first {
        case "help", "--help", "-h": return .help
        case "--version", "version": return .version
        case "run": return try parseRun(Array(arguments.dropFirst()))
        case "config": return try parseConfig(Array(arguments.dropFirst()))
        case "history": return try parseHistory(Array(arguments.dropFirst()))
        default:
            var index = 0
            let options = try parseSend(arguments, index: &index, stopAtCommand: false)
            guard index == arguments.count else { throw CLIError.usage("Unexpected argument: \(arguments[index])") }
            return .send(options)
        }
    }

    private static func parseRun(_ arguments: [String]) throws -> CLICommand {
        var index = 0
        let options = try parseSend(arguments, index: &index, stopAtCommand: true)
        let command = Array(arguments[index...])
        guard !command.isEmpty else { throw CLIError.usage("notify run requires a command") }
        return .run(options: options, command: command)
    }

    private static func parseSend(
        _ arguments: [String], index: inout Int, stopAtCommand: Bool
    ) throws -> SendOptions {
        var result = SendOptions()
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "--" { index += 1; break }
            if stopAtCommand, !argument.hasPrefix("-") { break }
            switch argument {
            case "-m", "--message": result.message = try value(arguments, &index, for: argument)
            case "-t", "--title": result.title = try value(arguments, &index, for: argument)
            case "-s", "--subtitle": result.subtitle = try value(arguments, &index, for: argument)
            case "--markdown": result.markdown = try value(arguments, &index, for: argument)
            case "-g", "--group": result.group = try value(arguments, &index, for: argument)
            case "--level":
                let raw = try value(arguments, &index, for: argument)
                guard let level = BarkLevel(rawValue: raw) else { throw CLIError.usage("Invalid level: \(raw)") }
                result.level = level
            case "--sound": result.sound = try value(arguments, &index, for: argument)
            case "--icon": result.icon = try value(arguments, &index, for: argument)
            case "--image": result.image = try value(arguments, &index, for: argument)
            case "--url": result.url = try value(arguments, &index, for: argument)
            case "--copy": result.copy = try value(arguments, &index, for: argument)
            case "--volume": result.volume = try integer(arguments, &index, for: argument, range: 0...10)
            case "--badge": result.badge = try integer(arguments, &index, for: argument)
            case "--ttl": result.ttl = try integer(arguments, &index, for: argument, range: 1...Int.max)
            case "--call": result.call = true; index += 1
            case "--auto-copy": result.autoCopy = true; index += 1
            case "--archive": result.archive = true; index += 1
            case "--no-archive": result.archive = false; index += 1
            case "--no-action": result.noAction = true; index += 1
            case "--id": result.id = try value(arguments, &index, for: argument)
            case "-q", "--quiet": result.quiet = true; index += 1
            default:
                if !stopAtCommand, !argument.hasPrefix("-"), result.message == nil {
                    result.message = argument
                    index += 1
                } else if stopAtCommand {
                    return result
                } else {
                    throw CLIError.usage("Unknown option: \(argument)")
                }
            }
        }
        return result
    }

    private static func parseConfig(_ arguments: [String]) throws -> CLICommand {
        guard let action = arguments.first else { return .config(.show) }
        if action == "show" { return .config(.show) }
        if action == "test" { return .config(.test) }
        guard action == "set" else { throw CLIError.usage("Unknown config command: \(action)") }
        var updates = ConfigUpdates()
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--server": updates.server = try value(arguments, &index, for: argument)
            case "--device": updates.device = try value(arguments, &index, for: argument)
            case "--group": updates.group = try value(arguments, &index, for: argument)
            case "--sound": updates.sound = try value(arguments, &index, for: argument)
            case "--username": updates.username = try value(arguments, &index, for: argument)
            case "--password": updates.password = try value(arguments, &index, for: argument)
            case "--level":
                let raw = try value(arguments, &index, for: argument)
                guard let level = BarkLevel(rawValue: raw) else { throw CLIError.usage("Invalid level: \(raw)") }
                updates.level = level
            case "--archive": updates.archive = true; index += 1
            case "--no-archive": updates.archive = false; index += 1
            case "--no-auth": updates.noAuth = true; index += 1
            default: throw CLIError.usage("Unknown config option: \(argument)")
            }
        }
        return .config(.set(updates))
    }

    private static func parseHistory(_ arguments: [String]) throws -> CLICommand {
        var search: String?
        var limit = 20
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--search": search = try value(arguments, &index, for: "--search")
            case "--limit": limit = try integer(arguments, &index, for: "--limit", range: 1...500)
            default: throw CLIError.usage("Unknown history option: \(arguments[index])")
            }
        }
        return .history(search: search, limit: limit)
    }

    private static func value(_ arguments: [String], _ index: inout Int, for option: String) throws -> String {
        guard index + 1 < arguments.count else { throw CLIError.usage("\(option) requires a value") }
        index += 2
        return arguments[index - 1]
    }

    private static func integer(
        _ arguments: [String], _ index: inout Int, for option: String,
        range: ClosedRange<Int>? = nil
    ) throws -> Int {
        let raw = try value(arguments, &index, for: option)
        guard let result = Int(raw), range?.contains(result) ?? true else {
            throw CLIError.usage("Invalid value for \(option): \(raw)")
        }
        return result
    }
}

enum CLIError: LocalizedError {
    case usage(String)
    case missingMessage

    var errorDescription: String? {
        switch self {
        case .usage(let message): message
        case .missingMessage: "Provide a message argument, use --message, or pipe text through stdin."
        }
    }
}
