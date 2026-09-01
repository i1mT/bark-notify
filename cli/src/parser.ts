import { barkLevels, CliError, type BarkLevel, type CliCommand, type ConfigUpdates, type SendOptions } from "./types.js";

export function emptySendOptions(): SendOptions {
  return { call: false, autoCopy: false, noAction: false, quiet: false };
}

export function parseArguments(arguments_: string[]): CliCommand {
  const [first] = arguments_;
  if (first === "help" || first === "--help" || first === "-h") return { kind: "help" };
  if (first === "version" || first === "--version") return { kind: "version" };
  if (first === "run") return parseRun(arguments_.slice(1));
  if (first === "config") return parseConfig(arguments_.slice(1));
  if (first === "history") return parseHistory(arguments_.slice(1));
  if (first === "agent-hook") return parseAgentHook(arguments_.slice(1));
  const result = parseSend(arguments_, false);
  if (result.index !== arguments_.length) usage(`Unexpected argument: ${arguments_[result.index]}`);
  return { kind: "send", options: result.options };
}

function parseAgentHook(arguments_: string[]): CliCommand {
  const [subcommand, ...rest] = arguments_;
  if (subcommand === "install") {
    let agents: string[] | undefined;
    let all = false;
    let dryRun = false;
    for (let index = 0; index < rest.length;) {
      const argument = rest[index];
      if (argument === "--all") { all = true; index += 1; continue; }
      if (argument === "--dry-run") { dryRun = true; index += 1; continue; }
      if (argument === "--agents") {
        const [raw, next] = value(rest, index, argument);
        agents = raw.split(",").map((item) => item.trim()).filter(Boolean);
        index = next;
        continue;
      }
      usage(`Unknown agent-hook install option: ${argument}`);
    }
    if (all && agents) usage("Use either --all or --agents, not both");
    return { kind: "agent-hook-install", ...(agents ? { agents } : {}), all, dryRun };
  }
  if (subcommand === "receive") {
    const [agent, payloadArgument, ...extra] = rest;
    if (!agent || extra.length > 0) usage("notify agent-hook receive requires an agent and optional JSON payload");
    return { kind: "agent-hook-receive", agent, ...(payloadArgument ? { payloadArgument } : {}) };
  }
  usage("notify agent-hook requires install or receive");
}

function parseRun(arguments_: string[]): CliCommand {
  const result = parseSend(arguments_, true);
  const command = arguments_.slice(result.index);
  if (command.length === 0) usage("notify run requires a command");
  return { kind: "run", options: result.options, command };
}

function parseSend(arguments_: string[], stopAtCommand: boolean): { options: SendOptions; index: number } {
  const options = emptySendOptions();
  let index = 0;
  while (index < arguments_.length) {
    const argument = arguments_[index];
    if (argument === "--") { index += 1; break; }
    if (stopAtCommand && !argument?.startsWith("-")) break;
    switch (argument) {
      case "-m": case "--message": [options.message, index] = value(arguments_, index, argument); break;
      case "-t": case "--title": [options.title, index] = value(arguments_, index, argument); break;
      case "-s": case "--subtitle": [options.subtitle, index] = value(arguments_, index, argument); break;
      case "--markdown": [options.markdown, index] = value(arguments_, index, argument); break;
      case "-g": case "--group": [options.group, index] = value(arguments_, index, argument); break;
      case "--level": [options.level, index] = levelValue(arguments_, index, argument); break;
      case "--sound": [options.sound, index] = value(arguments_, index, argument); break;
      case "--icon": [options.icon, index] = value(arguments_, index, argument); break;
      case "--image": [options.image, index] = value(arguments_, index, argument); break;
      case "--url": [options.url, index] = value(arguments_, index, argument); break;
      case "--copy": [options.copy, index] = value(arguments_, index, argument); break;
      case "--volume": [options.volume, index] = integer(arguments_, index, argument, 0, 10); break;
      case "--badge": [options.badge, index] = integer(arguments_, index, argument); break;
      case "--ttl": [options.ttl, index] = integer(arguments_, index, argument, 1); break;
      case "--call": options.call = true; index += 1; break;
      case "--auto-copy": options.autoCopy = true; index += 1; break;
      case "--archive": options.archive = true; index += 1; break;
      case "--no-archive": options.archive = false; index += 1; break;
      case "--no-action": options.noAction = true; index += 1; break;
      case "--id": [options.id, index] = value(arguments_, index, argument); break;
      case "-q": case "--quiet": options.quiet = true; index += 1; break;
      default:
        if (!stopAtCommand && argument && !argument.startsWith("-") && options.message === undefined) {
          options.message = argument;
          index += 1;
        } else if (stopAtCommand) {
          return { options, index };
        } else {
          usage(`Unknown option: ${argument}`);
        }
    }
  }
  return { options, index };
}

function parseConfig(arguments_: string[]): CliCommand {
  const action = arguments_[0] ?? "show";
  if (action === "show") return { kind: "config-show" };
  if (action === "path") return { kind: "config-path" };
  if (action === "test") return { kind: "config-test" };
  if (action !== "set") usage(`Unknown config command: ${action}`);
  const updates: ConfigUpdates = { noAuth: false, passwordStdin: false };
  let index = 1;
  while (index < arguments_.length) {
    const argument = arguments_[index];
    switch (argument) {
      case "--server": [updates.server, index] = value(arguments_, index, argument); break;
      case "--device": [updates.deviceKey, index] = value(arguments_, index, argument); break;
      case "--group": [updates.group, index] = value(arguments_, index, argument); break;
      case "--sound": [updates.sound, index] = value(arguments_, index, argument); break;
      case "--username": [updates.username, index] = value(arguments_, index, argument); break;
      case "--password": [updates.password, index] = value(arguments_, index, argument); break;
      case "--level": [updates.level, index] = levelValue(arguments_, index, argument); break;
      case "--archive": updates.archive = true; index += 1; break;
      case "--no-archive": updates.archive = false; index += 1; break;
      case "--no-auth": updates.noAuth = true; index += 1; break;
      case "--password-stdin": updates.passwordStdin = true; index += 1; break;
      default: usage(`Unknown config option: ${argument}`);
    }
  }
  if (updates.password !== undefined && updates.passwordStdin) usage("Use either --password or --password-stdin, not both");
  return { kind: "config-set", updates };
}

function parseHistory(arguments_: string[]): CliCommand {
  let search: string | undefined;
  let limit = 20;
  let index = 0;
  while (index < arguments_.length) {
    const argument = arguments_[index];
    if (argument === "--search") [search, index] = value(arguments_, index, argument);
    else if (argument === "--limit") [limit, index] = integer(arguments_, index, argument, 1, 500);
    else usage(`Unknown history option: ${argument}`);
  }
  return search === undefined ? { kind: "history", limit } : { kind: "history", search, limit };
}

function value(arguments_: string[], index: number, option: string): [string, number] {
  const result = arguments_[index + 1];
  if (result === undefined) usage(`${option} requires a value`);
  return [result, index + 2];
}

function integer(arguments_: string[], index: number, option: string, minimum?: number, maximum?: number): [number, number] {
  const [raw, next] = value(arguments_, index, option);
  const result = Number(raw);
  if (!Number.isInteger(result) || (minimum !== undefined && result < minimum) || (maximum !== undefined && result > maximum)) {
    usage(`Invalid value for ${option}: ${raw}`);
  }
  return [result, next];
}

function levelValue(arguments_: string[], index: number, option: string): [BarkLevel, number] {
  const [raw, next] = value(arguments_, index, option);
  if (!barkLevels.includes(raw as BarkLevel)) usage(`Invalid level: ${raw}`);
  return [raw as BarkLevel, next];
}

function usage(message: string): never {
  throw new CliError(message, true);
}
