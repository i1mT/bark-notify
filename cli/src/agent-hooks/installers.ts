import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { agentDefinitions } from "./catalog.js";
import { deepSeekConfigured, deepSeekProfiles, installDeepSeek } from "./deepseek.js";
import { commandHandler, managedMarker, opencodePlugin } from "./generated.js";
import { agentHome, exists, findExecutable, hookInvocation, powershellInvocation, readJson, writeJson, writeText } from "./filesystem.js";
import type { AgentId, DetectionResult, InstallResult } from "./model.js";

interface Context { home: string; dshHome: string; dryRun: boolean; executable?: string }

export async function detectAgents(environment: NodeJS.ProcessEnv = process.env): Promise<DetectionResult[]> {
  const home = agentHome(environment);
  const dshHome = environment.DSH_HOME ?? join(home, ".dsh");
  const results: DetectionResult[] = [];
  for (const definition of agentDefinitions) {
    const executable = await findExecutable(definition.commands, environment);
    const evidence = await detectionEvidence(definition.id, home, dshHome);
    results.push({
      definition,
      detected: Boolean(executable || evidence),
      configured: await isConfigured(definition.id, home, dshHome),
      ...(executable ? { executable } : {}),
      ...(evidence ? { evidence } : {}),
    });
  }
  return results;
}

export async function installAgentHooks(ids: AgentId[], dryRun: boolean, environment: NodeJS.ProcessEnv = process.env): Promise<InstallResult[]> {
  const detections = await detectAgents(environment);
  const home = agentHome(environment);
  const dshHome = environment.DSH_HOME ?? join(home, ".dsh");
  const results: InstallResult[] = [];
  for (const id of ids) {
    const detection = detections.find((item) => item.definition.id === id)!;
    const context: Context = { home, dshHome, dryRun, ...(detection.executable ? { executable: detection.executable } : {}) };
    results.push(...await installOne(id, context));
  }
  return results;
}

async function installOne(id: AgentId, context: Context): Promise<InstallResult[]> {
  if (id === "deepseek") return installDeepSeek(context.dshHome, context.executable, context.dryRun);
  if (id === "opencode") return [await installOpenCode(context)];
  const path = configPath(id, context.home);
  const root = await readJson(path);
  const token = `agent-hook receive ${id}`;
  if (JSON.stringify(root).includes(token)) return [{ agent: id, path, changed: false }];
  switch (id) {
    case "codex": case "claude": appendNested(root, "Stop", { hooks: [commandHandler(id, 10)] }); break;
    case "grok": appendNested(root, "Stop", { hooks: [commandHandler(id, 10)] }); break;
    case "gemini": appendNested(root, "AfterAgent", { matcher: "*", hooks: [{ name: "barkdesk-notify", ...commandHandler(id, 10_000) }] }); break;
    case "cursor": {
      if (root.version === undefined) root.version = 1;
      appendDirect(root, "stop", { command: hookInvocation(id).command, timeout: 10 });
      break;
    }
    case "copilot": {
      if (root.version === undefined) root.version = 1;
      appendDirect(root, "agentStop", { type: "command", bash: hookInvocation(id).command, powershell: powershellInvocation(id), timeoutSec: 10 });
      break;
    }
    default: throw new Error(`No hook installer is available for ${id}.`);
  }
  await writeJson(path, root, context.dryRun);
  return [{ agent: id, path, changed: true }];
}

async function installOpenCode(context: Context): Promise<InstallResult> {
  const path = configPath("opencode", context.home);
  const current = await readOptional(path);
  if (current && !current.includes(managedMarker)) {
    throw new Error(`Refusing to overwrite an unmanaged OpenCode plugin: ${path}`);
  }
  const next = opencodePlugin();
  const changed = current !== next;
  if (changed && !context.dryRun) await writeText(path, next);
  return { agent: "opencode", path, changed };
}

function appendNested(root: Record<string, unknown>, event: string, entry: Record<string, unknown>): void {
  const hooks = object(root.hooks);
  const list = array(hooks[event]);
  list.push(entry);
  hooks[event] = list;
  root.hooks = hooks;
}

function appendDirect(root: Record<string, unknown>, event: string, entry: Record<string, unknown>): void {
  const hooks = object(root.hooks);
  const list = array(hooks[event]);
  list.push(entry);
  hooks[event] = list;
  root.hooks = hooks;
}

function configPath(id: Exclude<AgentId, "deepseek">, home: string): string {
  const paths: Record<Exclude<AgentId, "deepseek">, string> = {
    codex: join(home, ".codex", "hooks.json"),
    claude: join(home, ".claude", "settings.json"),
    grok: join(home, ".grok", "hooks", "barkdesk-notify.json"),
    cursor: join(home, ".cursor", "hooks.json"),
    gemini: join(home, ".gemini", "settings.json"),
    opencode: join(home, ".config", "opencode", "plugins", "barkdesk-notify.js"),
    copilot: join(home, ".copilot", "hooks", "barkdesk-notify.json"),
  };
  return paths[id];
}

async function detectionEvidence(id: AgentId, home: string, dshHome: string): Promise<string | undefined> {
  if (id === "deepseek") return (await deepSeekProfiles(dshHome)).length ? join(dshHome, "profiles") : undefined;
  const path = configPath(id, home);
  const directory = id === "opencode" ? join(home, ".config", "opencode") : join(home, `.${id === "claude" ? "claude" : id}`);
  if (await exists(path)) return path;
  if (await exists(directory)) return directory;
  if (id === "cursor" && process.platform === "darwin" && await exists("/Applications/Cursor.app")) return "/Applications/Cursor.app";
  return undefined;
}

async function isConfigured(id: AgentId, home: string, dshHome: string): Promise<boolean> {
  if (id === "deepseek") return deepSeekConfigured(dshHome);
  return (await readOptional(configPath(id, home))).includes(`agent-hook receive ${id}`);
}

function object(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}
function array(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }
async function readOptional(path: string): Promise<string> { try { return await readFile(path, "utf8"); } catch { return ""; } }
