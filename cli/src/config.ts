import { chmod, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir, platform } from "node:os";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";
import { barkLevels, CliError, type BarkLevel, type ResolvedConfig, type StoredConfig } from "./types.js";

export function getConfigPath(environment: NodeJS.ProcessEnv = process.env): string {
  if (environment.BARKDESK_CONFIG) return environment.BARKDESK_CONFIG;
  const home = homedir();
  if (platform() === "win32") return join(environment.APPDATA ?? join(home, "AppData", "Roaming"), "BarkDesk", "config.json");
  if (platform() === "darwin") return join(home, "Library", "Application Support", "BarkDesk", "cli.json");
  return join(environment.XDG_CONFIG_HOME ?? join(home, ".config"), "barkdesk", "config.json");
}

export async function loadStoredConfig(path = getConfigPath()): Promise<StoredConfig> {
  try {
    const parsed: unknown = JSON.parse(await readFile(path, "utf8"));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new CliError(`Invalid configuration file: ${path}`);
    return parsed as StoredConfig;
  } catch (error) {
    if (isErrorCode(error, "ENOENT")) return {};
    if (error instanceof SyntaxError) throw new CliError(`Invalid JSON in configuration file: ${path}`);
    throw error;
  }
}

export async function saveStoredConfig(config: StoredConfig, path = getConfigPath()): Promise<void> {
  const directory = dirname(path);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const temporary = join(directory, `.config-${randomUUID()}.tmp`);
  await writeFile(temporary, `${JSON.stringify(config, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, path);
  if (platform() !== "win32") await chmod(path, 0o600);
}

export async function resolveConfig(environment: NodeJS.ProcessEnv = process.env): Promise<ResolvedConfig> {
  const stored = await loadStoredConfig(getConfigPath(environment));
  const deviceFromFile = await secretFromFile(environment.BARK_DEVICE_KEY_FILE);
  const passwordFromFile = await secretFromFile(environment.BARK_PASSWORD_FILE);
  const rawLevel = environment.BARK_LEVEL ?? stored.level ?? "active";
  if (!barkLevels.includes(rawLevel as BarkLevel)) throw new CliError(`Invalid BARK_LEVEL: ${rawLevel}`);
  const config: ResolvedConfig = {
    server: environment.BARK_SERVER ?? stored.server ?? "",
    deviceKey: environment.BARK_DEVICE_KEY ?? deviceFromFile ?? stored.deviceKey ?? "",
    group: environment.BARK_GROUP ?? stored.group ?? "terminal",
    level: rawLevel as BarkLevel,
    archive: environment.BARK_ARCHIVE === undefined ? (stored.archive ?? true) : parseBoolean(environment.BARK_ARCHIVE, "BARK_ARCHIVE"),
  };
  const username = environment.BARK_USERNAME ?? stored.username;
  const password = environment.BARK_PASSWORD ?? passwordFromFile ?? stored.password;
  const sound = environment.BARK_SOUND ?? stored.sound;
  if (username) config.username = username;
  if (password) config.password = password;
  if (sound) config.sound = sound;
  return validateConfig(config);
}

export function validateConfig(config: ResolvedConfig): ResolvedConfig {
  let url: URL;
  try { url = new URL(config.server); } catch { throw new CliError("Configure a valid Bark Server URL with notify config set --server URL"); }
  if (!(["http:", "https:"] as string[]).includes(url.protocol) || !url.hostname) {
    throw new CliError("Bark Server must use http:// or https://");
  }
  if (!config.deviceKey.trim()) throw new CliError("Configure a Device Key with notify config set --device KEY");
  if ((config.username && !config.password) || (!config.username && config.password)) {
    throw new CliError("Basic Auth requires both username and password");
  }
  return { ...config, server: config.server.replace(/\/+$/, ""), deviceKey: config.deviceKey.trim() };
}

export function masked(value: string | undefined): string {
  if (!value) return "Not configured";
  return `••••${value.slice(-4)}`;
}

async function secretFromFile(path: string | undefined): Promise<string | undefined> {
  if (!path) return undefined;
  return (await readFile(path, "utf8")).trim();
}

function parseBoolean(value: string, name: string): boolean {
  if (["1", "true", "yes", "on"].includes(value.toLowerCase())) return true;
  if (["0", "false", "no", "off"].includes(value.toLowerCase())) return false;
  throw new CliError(`${name} must be true or false`);
}

function isErrorCode(error: unknown, code: string): boolean {
  return error instanceof Error && "code" in error && error.code === code;
}
