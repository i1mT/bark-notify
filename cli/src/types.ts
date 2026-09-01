export const barkLevels = ["active", "timeSensitive", "passive", "critical"] as const;
export type BarkLevel = (typeof barkLevels)[number];

export interface StoredConfig {
  server?: string;
  deviceKey?: string;
  username?: string;
  password?: string;
  group?: string;
  level?: BarkLevel;
  sound?: string;
  archive?: boolean;
}

export interface ResolvedConfig {
  server: string;
  deviceKey: string;
  username?: string;
  password?: string;
  group: string;
  level: BarkLevel;
  sound?: string;
  archive: boolean;
}

export interface SendOptions {
  message?: string;
  title?: string;
  subtitle?: string;
  markdown?: string;
  group?: string;
  level?: BarkLevel;
  sound?: string;
  icon?: string;
  image?: string;
  url?: string;
  copy?: string;
  volume?: number;
  badge?: number;
  ttl?: number;
  call: boolean;
  autoCopy: boolean;
  archive?: boolean;
  noAction: boolean;
  id?: string;
  quiet: boolean;
}

export interface ConfigUpdates extends StoredConfig {
  noAuth: boolean;
  passwordStdin: boolean;
}

export type CliCommand =
  | { kind: "send"; options: SendOptions }
  | { kind: "run"; options: SendOptions; command: string[] }
  | { kind: "config-show" }
  | { kind: "config-path" }
  | { kind: "config-test" }
  | { kind: "config-set"; updates: ConfigUpdates }
  | { kind: "history"; search?: string; limit: number }
  | { kind: "agent-hook-install"; agents?: string[]; all: boolean; dryRun: boolean }
  | { kind: "agent-hook-receive"; agent: string; payloadArgument?: string }
  | { kind: "help" }
  | { kind: "version" };

export interface BarkPayload {
  device_key: string;
  title?: string;
  subtitle?: string;
  body: string;
  markdown?: string;
  level?: BarkLevel;
  volume?: number;
  badge?: number;
  call?: "1";
  autoCopy?: "1";
  copy?: string;
  sound?: string;
  icon?: string;
  image?: string;
  group?: string;
  isArchive?: "1";
  ttl?: number;
  url?: string;
  action?: "none";
  id?: string;
}

export interface HistoryRecord {
  createdAt: string;
  status: "success" | "failure";
  source: "send" | "run" | "agent-hook";
  title?: string;
  body: string;
  group?: string;
  httpStatus?: number;
  error?: string;
  command?: string;
  exitCode?: number;
  durationSeconds?: number;
}

export class CliError extends Error {
  constructor(message: string, readonly showHelpHint = false) {
    super(message);
    this.name = "CliError";
  }
}
