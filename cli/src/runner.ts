import { constants } from "node:os";
import { spawn } from "node:child_process";
import { appendHistory, getHistoryPath, readHistory } from "./history.js";
import { getConfigPath, loadStoredConfig, masked, resolveConfig, saveStoredConfig } from "./config.js";
import { BarkHttpError, makePayload, push, testConnection } from "./bark.js";
import { parseArguments } from "./parser.js";
import { CliError, type CliCommand, type ConfigUpdates, type HistoryRecord, type SendOptions, type StoredConfig } from "./types.js";
import { packageVersion } from "./version.js";
import { installCommand as installAgentHooksCommand, receiveCommand as receiveAgentHookCommand } from "./agent-hooks/command.js";

export async function run(arguments_: string[]): Promise<number> {
  try { return await execute(parseArguments(arguments_)); }
  catch (error) {
    process.stderr.write(`Error: ${messageOf(error)}\n`);
    if (error instanceof CliError && error.showHelpHint) process.stderr.write("Run 'notify --help' for usage.\n");
    return 1;
  }
}

async function execute(command: CliCommand): Promise<number> {
  switch (command.kind) {
    case "help": console.log(helpText); return 0;
    case "version": console.log(`notify ${packageVersion}`); return 0;
    case "config-show": await showConfig(); return 0;
    case "config-path": console.log(getConfigPath()); return 0;
    case "config-test": for (const line of await testConnection(await resolveConfig())) console.log(line); return 0;
    case "config-set": await updateConfig(command.updates); return 0;
    case "history": await showHistory(command.search, command.limit); return 0;
    case "agent-hook-install": return installAgentHooksCommand(command.agents, command.all, command.dryRun);
    case "agent-hook-receive": return receiveAgentHookCommand(command.agent, command.payloadArgument, (options) => deliver(options, "agent-hook"));
    case "send": return sendCommand(command.options);
    case "run": return runCommand(command.options, command.command);
  }
}

async function sendCommand(options: SendOptions): Promise<number> {
  if (!options.message && !options.markdown && !process.stdin.isTTY) options.message = (await readStandardInput()).trimEnd();
  if (!(options.message ?? options.markdown ?? "").trim()) throw new CliError("Provide a message, use --message, or pipe text through stdin.", true);
  await deliver(options, "send");
  if (!options.quiet) console.log("✓ Notification sent");
  return 0;
}

async function runCommand(options: SendOptions, command: string[]): Promise<number> {
  const start = Date.now();
  const result = await spawnCommand(command);
  const durationSeconds = (Date.now() - start) / 1000;
  const succeeded = result.code === 0 && result.signal === null;
  const exitCode = result.signal ? 128 + signalNumber(result.signal) : (result.code ?? 1);
  const commandText = command.map(shellQuote).join(" ");
  if (!options.title) options.title = succeeded ? "Command completed" : "Command failed";
  if (!options.message && !options.markdown) {
    const exitLine = succeeded ? "" : `\nExit Code: ${exitCode}`;
    options.message = `${succeeded ? "✅" : "❌"} ${options.title}\n\n${commandText}${exitLine}\nDuration: ${formatDuration(durationSeconds)}`;
  }
  if (!succeeded && !options.level) options.level = "timeSensitive";
  try {
    await deliver(options, "run", { command: commandText, exitCode, durationSeconds });
    if (!options.quiet) console.log("✓ Command notification sent");
  } catch (error) {
    process.stderr.write(`Warning: could not send notification: ${messageOf(error)}\n`);
  }
  return exitCode;
}

async function deliver(
  options: SendOptions,
  source: HistoryRecord["source"],
  metadata: Pick<HistoryRecord, "command" | "exitCode" | "durationSeconds"> = {},
): Promise<void> {
  const config = await resolveConfig();
  const payload = makePayload(options, config);
  const base = {
    createdAt: new Date().toISOString(), source, body: payload.body,
    ...(payload.title ? { title: payload.title } : {}),
    ...(payload.group ? { group: payload.group } : {}), ...metadata,
  };
  try {
    const result = await push(payload, config);
    await appendHistory({ ...base, status: "success", httpStatus: result.httpStatus });
  } catch (error) {
    const httpStatus = error instanceof BarkHttpError ? error.status : undefined;
    await appendHistory({ ...base, status: "failure", ...(httpStatus ? { httpStatus } : {}), error: messageOf(error) });
    throw error;
  }
}

async function showConfig(): Promise<void> {
  const path = getConfigPath();
  const stored = await loadStoredConfig(path);
  console.log(`Config: ${path}`);
  console.log(`Server: ${process.env.BARK_SERVER ?? stored.server ?? "Not configured"}`);
  console.log(`Device: ${masked(process.env.BARK_DEVICE_KEY ?? stored.deviceKey)}`);
  console.log(`Authentication: ${(process.env.BARK_USERNAME ?? stored.username) ? "basic" : "none"}`);
  console.log(`Group: ${process.env.BARK_GROUP ?? stored.group ?? "terminal"}`);
  console.log(`Level: ${process.env.BARK_LEVEL ?? stored.level ?? "active"}`);
  console.log(`Sound: ${process.env.BARK_SOUND ?? stored.sound ?? "default"}`);
  const archive = process.env.BARK_ARCHIVE?.toLowerCase();
  const archivesByDefault = archive ? !["0", "false", "no", "off"].includes(archive) : (stored.archive ?? true);
  console.log(`Archive: ${archivesByDefault ? "yes" : "no"}`);
  console.log(`History: ${getHistoryPath()}`);
}

async function updateConfig(updates: ConfigUpdates): Promise<void> {
  const path = getConfigPath();
  const current = await loadStoredConfig(path);
  const next: StoredConfig = { ...current };
  for (const key of ["server", "deviceKey", "group", "level", "sound", "username", "password", "archive"] as const) {
    const value = updates[key];
    if (value !== undefined) Object.assign(next, { [key]: value });
  }
  if (updates.passwordStdin) next.password = (await readStandardInput()).trimEnd();
  if (updates.noAuth) { delete next.username; delete next.password; }
  await saveStoredConfig(next, path);
  console.log(`✓ Configuration saved to ${path}`);
}

async function showHistory(search: string | undefined, limit: number): Promise<void> {
  const records = await readHistory(search, limit);
  if (records.length === 0) { console.log("No notification history."); return; }
  for (const record of records) {
    const heading = record.title || record.body.split("\n")[0] || "Notification";
    console.log(`${record.status === "success" ? "✓" : "✗"} ${record.createdAt.replace("T", " ").slice(0, 19)}  ${heading}  [${record.source}]`);
  }
}

function spawnCommand(command: string[]): Promise<{ code: number | null; signal: NodeJS.Signals | null }> {
  return new Promise((resolve) => {
    const child = spawn(command[0]!, command.slice(1), { stdio: "inherit", shell: false });
    child.once("error", (error) => { process.stderr.write(`Command error: ${error.message}\n`); resolve({ code: 127, signal: null }); });
    child.once("exit", (code, signal) => resolve({ code, signal }));
  });
}

async function readStandardInput(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  return Buffer.concat(chunks).toString("utf8");
}

function signalNumber(signal: NodeJS.Signals): number { return constants.signals[signal] ?? 0; }
function messageOf(error: unknown): string { return error instanceof Error ? error.message : String(error); }
function formatDuration(seconds: number): string {
  const total = Math.max(0, Math.round(seconds));
  if (total >= 3600) return `${Math.floor(total / 3600)}h ${Math.floor((total % 3600) / 60)}m ${total % 60}s`;
  if (total >= 60) return `${Math.floor(total / 60)}m ${total % 60}s`;
  return `${total}s`;
}
function shellQuote(value: string): string { return /^[\w./-]+$/.test(value) ? value : `'${value.replaceAll("'", "'\\''")}'`; }

export const helpText = `notify — send Bark notifications from Linux, macOS, or Windows

USAGE
  notify "Message"
  echo "Message" | notify -t "Title"
  notify run [notification options] -- command [arguments]
  notify config show|path|test|set [options]
  notify history [--search text] [--limit number]
  notify agent-hook install [--all | --agents LIST] [--dry-run]

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
      --markdown TEXT      Markdown body
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
  printf '%s' "$BARK_PASSWORD" | notify config set --username USER --password-stdin

SERVER ENVIRONMENT
  BARK_SERVER, BARK_DEVICE_KEY, BARK_DEVICE_KEY_FILE
  BARK_USERNAME, BARK_PASSWORD, BARK_PASSWORD_FILE
  BARK_GROUP, BARK_LEVEL, BARK_SOUND, BARK_ARCHIVE

CODING AGENT HOOKS
  notify agent-hook install
  notify agent-hook install --all
  notify agent-hook install --agents codex,claude,opencode
`;
