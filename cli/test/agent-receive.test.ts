import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

test("agent-hook receive sends one normalized notification and returns hook JSON", async () => {
  let received: Record<string, unknown> | undefined;
  const server = createServer((request, response) => {
    const chunks: Buffer[] = [];
    request.on("data", (chunk: Buffer) => chunks.push(chunk));
    request.on("end", () => {
      received = JSON.parse(Buffer.concat(chunks).toString("utf8")) as Record<string, unknown>;
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end('{"code":200,"message":"success"}');
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert(address && typeof address === "object");
  const directory = await mkdtemp(join(tmpdir(), "barkdesk-agent-receive-"));
  const main = fileURLToPath(new URL("../src/main.js", import.meta.url));
  const result = await runProcess(process.execPath, [main, "agent-hook", "receive", "codex"], {
    ...process.env,
    BARK_SERVER: `http://127.0.0.1:${address.port}`,
    BARK_DEVICE_KEY: "test-device",
    BARKDESK_HISTORY: join(directory, "history.jsonl"),
  }, JSON.stringify({ session_id: "s1", turn_id: "t1", cwd: "/work/demo", last_assistant_message: "All tests passed." }));
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));

  assert.equal(result.code, 0);
  assert.equal(result.stdout, "{}\n");
  assert.equal(received?.title, "Codex · demo · 任务完成");
  assert.equal(received?.body, "All tests passed.");
  assert.match(await readFile(join(directory, "history.jsonl"), "utf8"), /"source":"agent-hook"/);
});

test("agent-hook receive fails open when its input is invalid", async () => {
  const main = fileURLToPath(new URL("../src/main.js", import.meta.url));
  const result = await runProcess(process.execPath, [main, "agent-hook", "receive", "claude"], process.env, "not-json");
  assert.equal(result.code, 0);
  assert.equal(result.stdout, "{}\n");
});

function runProcess(command: string, arguments_: string[], environment: NodeJS.ProcessEnv, input: string): Promise<{ code: number | null; stdout: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, arguments_, { env: environment, stdio: ["pipe", "pipe", "inherit"] });
    const chunks: Buffer[] = [];
    child.stdout.on("data", (chunk: Buffer) => chunks.push(chunk));
    child.once("error", reject);
    child.once("exit", (code) => resolve({ code, stdout: Buffer.concat(chunks).toString("utf8") }));
    child.stdin.end(input);
  });
}
