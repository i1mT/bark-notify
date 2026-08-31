import assert from "node:assert/strict";
import { mkdtemp, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { loadStoredConfig, resolveConfig, saveStoredConfig } from "../src/config.js";

test("configuration is written with private permissions", async () => {
  const directory = await mkdtemp(join(tmpdir(), "barkdesk-cli-"));
  const path = join(directory, "nested", "config.json");
  await saveStoredConfig({ server: "https://bark.example.com", deviceKey: "secret" }, path);
  assert.equal((await stat(path)).mode & 0o777, process.platform === "win32" ? (await stat(path)).mode & 0o777 : 0o600);
  assert.deepEqual(await loadStoredConfig(path), { server: "https://bark.example.com", deviceKey: "secret" });
  assert.match(await readFile(path, "utf8"), /deviceKey/);
});

test("environment variables override file configuration", async () => {
  const directory = await mkdtemp(join(tmpdir(), "barkdesk-cli-env-"));
  const path = join(directory, "config.json");
  await saveStoredConfig({ server: "https://old.example.com", deviceKey: "old" }, path);
  const config = await resolveConfig({
    BARKDESK_CONFIG: path,
    BARK_SERVER: "https://new.example.com",
    BARK_DEVICE_KEY: "new",
    BARK_ARCHIVE: "false",
  });
  assert.equal(config.server, "https://new.example.com");
  assert.equal(config.deviceKey, "new");
  assert.equal(config.archive, false);
});
