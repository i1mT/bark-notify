import { constants } from "node:fs";
import { access, chmod, mkdir, readFile, rename, stat, writeFile } from "node:fs/promises";
import { delimiter, dirname, join, resolve } from "node:path";
import { homedir } from "node:os";

export function agentHome(environment: NodeJS.ProcessEnv = process.env): string {
  return environment.BARKDESK_AGENT_HOME ? resolve(environment.BARKDESK_AGENT_HOME) : homedir();
}

export async function exists(path: string): Promise<boolean> {
  try { await access(path, constants.F_OK); return true; }
  catch { return false; }
}

export async function findExecutable(names: string[], environment: NodeJS.ProcessEnv = process.env): Promise<string | undefined> {
  const suffixes = process.platform === "win32"
    ? (environment.PATHEXT ?? ".EXE;.CMD;.BAT").split(";")
    : [""];
  for (const directory of (environment.PATH ?? "").split(delimiter).filter(Boolean)) {
    for (const name of names) {
      for (const suffix of suffixes) {
        const candidate = join(directory, `${name}${suffix}`);
        if (await isExecutable(candidate)) return candidate;
      }
    }
  }
  return undefined;
}

export async function readJson(path: string): Promise<Record<string, unknown>> {
  if (!(await exists(path))) return {};
  const raw = await readFile(path, "utf8");
  try {
    const value: unknown = JSON.parse(raw);
    if (value !== null && typeof value === "object" && !Array.isArray(value)) return value as Record<string, unknown>;
  } catch (error) {
    throw new Error(`Cannot update invalid JSON file ${path}: ${messageOf(error)}`);
  }
  throw new Error(`Cannot update ${path}: its root value must be a JSON object.`);
}

export async function writeJson(path: string, value: unknown, dryRun = false): Promise<void> {
  if (dryRun) return;
  await writeText(path, `${JSON.stringify(value, null, 2)}\n`);
}

export async function writeText(path: string, value: string): Promise<void> {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  const temporary = `${path}.barkdesk-${process.pid}-${Date.now()}`;
  let mode = 0o600;
  try { mode = (await stat(path)).mode & 0o777; } catch { /* new file */ }
  await writeFile(temporary, value, { mode });
  await chmod(temporary, mode);
  await rename(temporary, path);
}

export function hookInvocation(agent: string): { command: string; node: string; entry: string; arguments: string[] } {
  const entry = resolve(process.argv[1] ?? "notify");
  const arguments_ = [entry, "agent-hook", "receive", agent];
  return {
    command: [process.execPath, ...arguments_].map(commandQuote).join(" "),
    node: process.execPath,
    entry,
    arguments: arguments_.slice(1),
  };
}

export function powershellInvocation(agent: string): string {
  const invocation = hookInvocation(agent);
  return `& ${powerShellQuote(invocation.node)} ${powerShellQuote(invocation.entry)} agent-hook receive ${agent}`;
}

function commandQuote(value: string): string {
  if (process.platform === "win32") return `"${value.replaceAll('"', '\\"')}"`;
  return /^[\w./:\\-]+$/.test(value) ? value : `'${value.replaceAll("'", "'\\''")}'`;
}

function powerShellQuote(value: string): string { return `'${value.replaceAll("'", "''")}'`; }

async function isExecutable(path: string): Promise<boolean> {
  try { await access(path, process.platform === "win32" ? constants.F_OK : constants.X_OK); return true; }
  catch { return false; }
}

function messageOf(error: unknown): string { return error instanceof Error ? error.message : String(error); }
