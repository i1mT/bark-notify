import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { installAgentHooks } from "../src/agent-hooks/installers.js";
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

test("installs the DeepSeek bridge configuration idempotently", async () => {
  const home = await mkdtemp(join(tmpdir(), "barkdesk-dsh-install-"));
  const profile = join(home, ".dsh", "profiles", "cli");
  await mkdir(profile, { recursive: true });
  await writeFile(join(profile, "package.json"), JSON.stringify({ dependencies: { "@deepseek-ai/dsh-hooks-claude-code": "1.0.0" } }));
  await mkdir(join(profile, "node_modules", "@deepseek-ai", "dsh-hooks-claude-code"), { recursive: true });
  await writeFile(join(profile, "node_modules", "@deepseek-ai", "dsh-hooks-claude-code", "package.json"), "{}");
  await writeFile(join(profile, "cordis.patch.yml"), "[]\n");
  const environment = { BARKDESK_AGENT_HOME: home, PATH: "" };

  const first = await installAgentHooks(["deepseek"], false, environment);
  assert(first.every((item) => item.changed));
  const patch = await readFile(join(profile, "cordis.patch.yml"), "utf8");
  assert.match(patch, /name: '@deepseek-ai\/dsh-hooks-claude-code'/);
  assert.match(patch, /config:\n    configPath:/);
  assert.match(await readFile(join(home, ".dsh", "barkdesk-notify-hooks.json"), "utf8"), /agent-hook receive deepseek/);

  const second = await installAgentHooks(["deepseek"], false, environment);
  assert(second.every((item) => !item.changed));
});
