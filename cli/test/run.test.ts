import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

test("run preserves the child exit code and still sends a notification", async () => {
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
  const directory = await mkdtemp(join(tmpdir(), "barkdesk-run-"));
  const main = fileURLToPath(new URL("../src/main.js", import.meta.url));
  const result = await runProcess(process.execPath, [main, "run", "--", process.execPath, "-e", "process.exit(3)"], {
    ...process.env,
    BARK_SERVER: `http://127.0.0.1:${address.port}`,
    BARK_DEVICE_KEY: "test-device",
    BARKDESK_HISTORY: join(directory, "history.jsonl"),
  });
  await new Promise<void>((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
  assert.equal(result.code, 3);
  assert.equal(received?.device_key, "test-device");
  assert.equal(received?.title, "Command failed");
  assert.match(await readFile(join(directory, "history.jsonl"), "utf8"), /"status":"success"/);
});

function runProcess(command: string, arguments_: string[], environment: NodeJS.ProcessEnv): Promise<{ code: number | null }> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, arguments_, { env: environment, stdio: "ignore" });
    child.once("error", reject);
    child.once("exit", (code) => resolve({ code }));
  });
}
