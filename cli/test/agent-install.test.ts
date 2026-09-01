import assert from "node:assert/strict";
import { chmod, mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { detectAgents, installAgentHooks } from "../src/agent-hooks/installers.js";
import { deepSeekProfiles } from "../src/agent-hooks/deepseek.js";

test("installs supported JSON hooks without replacing existing settings", async () => {
  const home = await mkdtemp(join(tmpdir(), "barkdesk-agent-install-"));
  await mkdir(join(home, ".claude"), { recursive: true });
  await writeFile(join(home, ".claude", "settings.json"), JSON.stringify({ theme: "dark", hooks: { Stop: [{ hooks: [{ type: "command", command: "existing-hook" }] }] } }));
  const environment = { BARKDESK_AGENT_HOME: home, PATH: "" };
  const ids = ["codex", "claude", "grok", "cursor", "gemini", "opencode", "copilot"] as const;

  const first = await installAgentHooks([...ids], false, environment);
  assert(first.every((item) => item.changed));
  const claude = JSON.parse(await readFile(join(home, ".claude", "settings.json"), "utf8")) as Record<string, unknown>;
  assert.equal(claude.theme, "dark");
  assert.match(JSON.stringify(claude), /existing-hook/);
  assert.match(JSON.stringify(claude), /agent-hook receive claude/);
  assert.match(await readFile(join(home, ".config", "opencode", "plugins", "barkdesk-notify.js"), "utf8"), /session\.idle/);
  assert.equal((await detectAgents(environment)).find((item) => item.definition.id === "opencode")?.configured, true);

  const second = await installAgentHooks([...ids], false, environment);
  assert(second.every((item) => !item.changed));
  const codexText = await readFile(join(home, ".codex", "hooks.json"), "utf8");
  assert.equal(codexText.match(/agent-hook receive codex/g)?.length, 1);
});

test("DeepSeek scan only returns actual profile directories", async () => {
  const dshHome = await mkdtemp(join(tmpdir(), "barkdesk-dsh-scan-"));
  await mkdir(join(dshHome, "profiles", "node_modules"), { recursive: true });
  await mkdir(join(dshHome, "profiles", "web"), { recursive: true });
  await writeFile(join(dshHome, "profiles", "web", "package.json"), "{}");
  assert.deepEqual(await deepSeekProfiles(dshHome), ["web"]);
});

test("installs a dependency-free native DeepSeek plugin idempotently", async () => {
  const home = await mkdtemp(join(tmpdir(), "barkdesk-dsh-install-"));
  const profile = join(home, ".dsh", "profiles", "cli");
  await mkdir(profile, { recursive: true });
  await writeFile(join(profile, "package.json"), "{}");
  await writeFile(join(profile, "cordis.patch.yml"), "[]\n");
  const bin = await fakeDsh(home, 0);
  const environment = { BARKDESK_AGENT_HOME: home, PATH: bin };

  const first = await installAgentHooks(["deepseek"], false, environment);
  assert(first.every((item) => item.changed));
  const patch = await readFile(join(profile, "cordis.patch.yml"), "utf8");
  assert.match(patch, /- insert:\n    - id: barkdesk-notify-agent-hook/);
  assert.match(patch, /name: '.*barkdesk-notify-plugin\.mjs'/);
  const plugin = await readFile(join(home, ".dsh", "barkdesk-notify-plugin.mjs"), "utf8");
  assert.match(plugin, /agent\/turn-stopping/);
  assert.match(plugin, /"agent-hook","receive","deepseek"/);

  const second = await installAgentHooks(["deepseek"], false, environment);
  assert(second.every((item) => !item.changed));
});

test("restores a DeepSeek profile when DSH rejects the native plugin", async () => {
  const home = await mkdtemp(join(tmpdir(), "barkdesk-dsh-rollback-"));
  const profile = join(home, ".dsh", "profiles", "web");
  await mkdir(profile, { recursive: true });
  await writeFile(join(profile, "package.json"), "{}");
  await writeFile(join(profile, "cordis.patch.yml"), "# original\n[]\n");
  const bin = await fakeDsh(home, 1);

  const results = await installAgentHooks(["deepseek"], false, { BARKDESK_AGENT_HOME: home, PATH: bin });
  assert.match(results.find((item) => item.error)?.error ?? "", /original patch was restored/);
  assert.equal(await readFile(join(profile, "cordis.patch.yml"), "utf8"), "# original\n[]\n");
});

async function fakeDsh(home: string, exitCode: number): Promise<string> {
  const bin = join(home, "bin");
  await mkdir(bin, { recursive: true });
  const path = join(bin, "dsh");
  await writeFile(path, `#!/bin/sh\nexit ${exitCode}\n`);
  await chmod(path, 0o755);
  return bin;
}
