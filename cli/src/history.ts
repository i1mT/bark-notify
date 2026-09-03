import { appendFile, chmod, mkdir, open, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { homedir, platform } from "node:os";
import { dirname, join } from "node:path";
import { randomUUID } from "node:crypto";
import type { HistoryRecord } from "./types.js";

const maximumBytes = 1_000_000;
const retainedRecords = 1_000;

export function getHistoryPath(environment: NodeJS.ProcessEnv = process.env): string {
  if (environment.BARKDESK_HISTORY) return environment.BARKDESK_HISTORY;
  const home = homedir();
  if (platform() === "win32") return join(environment.LOCALAPPDATA ?? join(home, "AppData", "Local"), "BarkDesk", "history.jsonl");
  if (platform() === "darwin") return join(home, "Library", "Application Support", "BarkDesk", "CLI", "history.jsonl");
  return join(environment.XDG_STATE_HOME ?? join(home, ".local", "state"), "barkdesk", "history.jsonl");
}

export async function appendHistory(record: HistoryRecord, path = getHistoryPath()): Promise<void> {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  await withHistoryLock(path, async () => {
    await appendFile(path, `${JSON.stringify(record)}\n`, { mode: 0o600 });
    if (platform() !== "win32") await chmod(path, 0o600);
    if ((await stat(path)).size > maximumBytes) await compact(path);
  });
}

export async function readHistory(search: string | undefined, limit: number, path = getHistoryPath()): Promise<HistoryRecord[]> {
  let content: string;
  try { content = await readFile(path, "utf8"); }
  catch (error) { if (isErrorCode(error, "ENOENT")) return []; throw error; }
  const query = search?.toLowerCase();
  return content.split("\n").filter(Boolean).flatMap((line) => {
    try { return [JSON.parse(line) as HistoryRecord]; } catch { return []; }
  }).filter((record) => !query || JSON.stringify(record).toLowerCase().includes(query)).slice(-limit).reverse();
}

async function compact(path: string): Promise<void> {
  const records = await readHistory(undefined, retainedRecords, path);
  const temporary = join(dirname(path), `.history-${randomUUID()}.tmp`);
  await writeFile(temporary, records.reverse().map((record) => JSON.stringify(record)).join("\n") + "\n", { mode: 0o600 });
  await rename(temporary, path);
}

function isErrorCode(error: unknown, code: string): boolean {
  return error instanceof Error && "code" in error && error.code === code;
}

async function withHistoryLock<T>(path: string, operation: () => Promise<T>): Promise<T> {
  const lockPath = `${path}.lock`;
  let handle;
  for (let attempt = 0; ; attempt += 1) {
    try { handle = await open(lockPath, "wx", 0o600); break; }
    catch (error) {
      if (!isErrorCode(error, "EEXIST") || attempt >= 80) throw error;
      const details = await stat(lockPath).catch(() => undefined);
      if (details && Date.now() - details.mtimeMs > 30_000) await unlink(lockPath).catch(() => undefined);
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
  }
  try { return await operation(); }
  finally {
    await handle.close();
    await unlink(lockPath).catch(() => undefined);
  }
}
