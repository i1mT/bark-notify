import { spawn } from "node:child_process";
import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import { deepSeekPlugin } from "./generated.js";
import { exists, writeText } from "./filesystem.js";
import type { InstallResult } from "./model.js";

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
  if (profiles.length === 0) return [{
    agent: "deepseek",
    path: join(dshHome, "profiles"),
    changed: false,
    error: "No DeepSeek Harness profiles were found.",
  }];
  const pluginPath = join(dshHome, "barkdesk-notify-plugin.mjs");
  const plugin = deepSeekPlugin();
  await validatePluginModule(plugin);
  const pluginChanged = await readOptional(pluginPath) !== plugin;
  if (pluginChanged && !dryRun) await writeText(pluginPath, plugin);
  const results: InstallResult[] = [{ agent: "deepseek", path: pluginPath, changed: pluginChanged }];
  for (const profile of profiles) {
    const profilePath = join(dshHome, "profiles", profile);
    const patchPath = join(profilePath, "cordis.patch.yml");
    try {
      const current = await readOptional(patchPath);
      if (current.includes(markerStart)) {
        results.push({ agent: "deepseek", path: patchPath, changed: false, detail: profile });
        continue;
      }
      const block = `${markerStart}\n- insert:\n    - id: barkdesk-notify-agent-hook\n      name: ${yamlQuote(pluginPath)}\n${markerEnd}`;
      const base = patchBase(current, patchPath);
      if (!dryRun) {
        if (!executable) throw new Error("The dsh command was not found, so the plugin cannot be installed safely.");
        await writeText(patchPath, `${base ? `${base}\n` : ""}${block}\n`);
        try { await validateProfile(executable, profile); }
        catch (error) {
          await writeText(patchPath, current);
          throw new Error(`DSH rejected the installed plugin and the original patch was restored: ${messageOf(error)}`);
        }
      }
      results.push({ agent: "deepseek", path: patchPath, changed: true, detail: profile });
    } catch (error) {
      results.push({ agent: "deepseek", path: patchPath, changed: false, detail: profile, error: messageOf(error) });
    }
  }
  return results;
}

export async function deepSeekConfigured(dshHome: string): Promise<boolean> {
  for (const profile of await deepSeekProfiles(dshHome)) {
    if ((await readOptional(join(dshHome, "profiles", profile, "cordis.patch.yml"))).includes(markerStart)) return true;
  }
  return false;
}

async function readOptional(path: string): Promise<string> {
  try { return await readFile(path, "utf8"); } catch { return ""; }
}

async function validatePluginModule(source: string): Promise<void> {
  const url = `data:text/javascript;base64,${Buffer.from(source).toString("base64")}`;
  const module: unknown = await import(url);
  if (module === null || typeof module !== "object" || typeof (module as { apply?: unknown }).apply !== "function") {
    throw new Error("Generated DeepSeek plugin does not export an apply function.");
  }
}

function validateProfile(executable: string, profile: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, ["--profile", profile, "--help"], { stdio: ["ignore", "ignore", "pipe"], shell: false });
    const errors: Buffer[] = [];
    child.stderr.on("data", (chunk: Buffer) => errors.push(chunk));
    child.once("error", reject);
    child.once("exit", (code, signal) => {
      if (code === 0 && signal === null) resolve();
      else reject(new Error(Buffer.concat(errors).toString("utf8").trim() || `${executable} exited with ${signal ?? code ?? 1}.`));
    });
  });
}

function yamlQuote(value: string): string { return `'${value.replaceAll("'", "''")}'`; }
function messageOf(error: unknown): string { return error instanceof Error ? error.message : String(error); }

function patchBase(value: string, path: string): string {
  const meaningful = value.split(/\r?\n/u).map((line) => line.trim()).filter((line) => line && !line.startsWith("#"));
  if (meaningful.length === 0) return value.trimEnd();
  if (meaningful.length === 1 && meaningful[0] === "[]") {
    return value.split(/\r?\n/u).filter((line) => line.trim() !== "[]").join("\n").trimEnd();
  }
  if (!meaningful[0]?.startsWith("- ")) throw new Error(`Cannot update ${path}: its root value must be a YAML list.`);
  return value.trimEnd();
}
