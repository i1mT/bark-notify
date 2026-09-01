import { spawn } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { commandHandler, managedMarker } from "./generated.js";
import { exists, readJson, writeJson, writeText } from "./filesystem.js";
import type { InstallResult } from "./model.js";

const packageName = "@deepseek-ai/dsh-hooks-claude-code";
const markerStart = "# barkdesk-notify agent-hook start";
const markerEnd = "# barkdesk-notify agent-hook end";

export async function deepSeekProfiles(dshHome: string): Promise<string[]> {
  const profiles = join(dshHome, "profiles");
  if (!(await exists(profiles))) return [];
  const entries = await readdir(profiles, { withFileTypes: true });
  const candidates = entries.filter((entry) => entry.isDirectory() && entry.name !== "node_modules");
  const valid = await Promise.all(candidates.map(async (entry) => ({
    name: entry.name,
    valid: await exists(join(profiles, entry.name, "package.json")),
  })));
  return valid.filter((entry) => entry.valid).map((entry) => entry.name).sort();
}

export async function installDeepSeek(dshHome: string, executable: string | undefined, dryRun: boolean): Promise<InstallResult[]> {
  const profiles = await deepSeekProfiles(dshHome);
  if (profiles.length === 0) throw new Error(`No DeepSeek Harness profiles were found in ${join(dshHome, "profiles")}.`);
  const hookPath = join(dshHome, "barkdesk-notify-hooks.json");
  const hookConfig = {
    description: managedMarker,
    hooks: { Stop: [{ hooks: [commandHandler("deepseek", 10)] }] },
  };
  const hookChanged = JSON.stringify(await readJson(hookPath)) !== JSON.stringify(hookConfig);
  if (hookChanged) await writeJson(hookPath, hookConfig, dryRun);
  const results: InstallResult[] = [{ agent: "deepseek", path: hookPath, changed: hookChanged }];
  for (const profile of profiles) {
    const profilePath = join(dshHome, "profiles", profile);
    const patchPath = join(profilePath, "cordis.patch.yml");
    const current = await readOptional(patchPath);
    if (current.includes(markerStart)) {
      results.push({ agent: "deepseek", path: patchPath, changed: false, detail: profile });
      continue;
    }
    if (!dryRun && !(await hasBridgePackage(profilePath))) {
      if (!executable) throw new Error(`Cannot install the DeepSeek hook bridge because the dsh command was not found.`);
      await run(executable, ["plugin", "--profile", profile, "add", packageName]);
    }
    const block = `${markerStart}\n- name: ${yamlQuote(packageName)}\n  config:\n    configPath: ${yamlQuote(hookPath)}\n${markerEnd}`;
    const base = patchBase(current, patchPath);
    if (!dryRun) await writeText(patchPath, `${base ? `${base}\n` : ""}${block}\n`);
    results.push({ agent: "deepseek", path: patchPath, changed: true, detail: profile });
  }
  return results;
}

export async function deepSeekConfigured(dshHome: string): Promise<boolean> {
  for (const profile of await deepSeekProfiles(dshHome)) {
    if ((await readOptional(join(dshHome, "profiles", profile, "cordis.patch.yml"))).includes(markerStart)) return true;
  }
  return false;
}

async function hasBridgePackage(profilePath: string): Promise<boolean> {
  const declared = (await readOptional(join(profilePath, "package.json"))).includes(`"${packageName}"`);
  const installed = await exists(join(profilePath, "node_modules", "@deepseek-ai", "dsh-hooks-claude-code", "package.json"));
  return declared && installed;
}

async function readOptional(path: string): Promise<string> {
  try { return await readFile(path, "utf8"); } catch { return ""; }
}

function run(command: string, arguments_: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, arguments_, { stdio: "inherit", shell: false });
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0 && signal === null) resolve();
      else reject(new Error(`${command} ${arguments_.join(" ")} failed with ${signal ?? `exit code ${code ?? 1}`}.`));
    });
  });
}

function yamlQuote(value: string): string { return `'${value.replaceAll("'", "''")}'`; }

function patchBase(value: string, path: string): string {
  const meaningful = value.split(/\r?\n/u).map((line) => line.trim()).filter((line) => line && !line.startsWith("#"));
  if (meaningful.length === 0) return value.trimEnd();
  if (meaningful.length === 1 && meaningful[0] === "[]") {
    return value.split(/\r?\n/u).filter((line) => line.trim() !== "[]").join("\n").trimEnd();
  }
  if (!meaningful[0]?.startsWith("- ")) throw new Error(`Cannot update ${path}: its root value must be a YAML list.`);
  return value.trimEnd();
}
