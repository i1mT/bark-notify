import assert from "node:assert/strict";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { appendHistory, readHistory } from "../src/history.js";

test("reads BarkDesk GUI records from the shared macOS history format", async () => {
  const directory = await mkdtemp(join(tmpdir(), "barkdesk-shared-history-"));
  const path = join(directory, "history.jsonl");
  const record = {
    id: "17cb65f6-f8c8-4a18-9762-fc9ab6182442",
    createdAt: "2026-09-03T09:00:00.000Z",
    status: "success",
    source: "gui",
    title: "BarkDesk",
    body: "Sent from app",
  };
  await writeFile(path, `${JSON.stringify(record)}\n`, "utf8");

  const records = await readHistory(undefined, 10, path);
  assert.equal(records.length, 1);
  assert.equal(records[0]?.id, record.id);
  assert.equal(records[0]?.source, "gui");
});

test("serializes concurrent writers without losing shared history", async () => {
  const directory = await mkdtemp(join(tmpdir(), "barkdesk-concurrent-history-"));
  const path = join(directory, "history.jsonl");
  await Promise.all(Array.from({ length: 30 }, (_, index) => appendHistory({
    id: `00000000-0000-4000-8000-${String(index).padStart(12, "0")}`,
    createdAt: new Date(index * 1_000).toISOString(),
    status: "success",
    source: "gui",
    body: `Record ${index}`,
  }, path)));

  const records = await readHistory(undefined, 100, path);
  assert.equal(records.length, 30);
  assert.equal(new Set(records.map((record) => record.id)).size, 30);
});
