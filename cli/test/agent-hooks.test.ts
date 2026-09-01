import assert from "node:assert/strict";
import test from "node:test";
import { normalizeEvent, notificationOptions } from "../src/agent-hooks/model.js";
import { formatInstallSummary } from "../src/agent-hooks/command.js";

test("normalizes Codex Stop input into a completion notification", () => {
  const event = normalizeEvent("codex", {
    session_id: "session-1",
    turn_id: "turn-2",
    cwd: "/workspace/my-project",
    last_assistant_message: "Implemented the requested change.",
  }, {});
  assert(event);
  assert.equal(event.message, "Implemented the requested change.");
  assert.equal(notificationOptions(event, "Codex").title, "Codex · my-project · 任务完成");
});

test("normalizes Gemini AfterAgent responses", () => {
  const event = normalizeEvent("gemini", { prompt_response: "Tests passed", cwd: "/tmp/demo" }, {});
  assert.equal(event?.message, "Tests passed");
  assert.equal(event?.status, "completed");
});

test("ignores Grok Stop events that do not represent the end of a turn", () => {
  assert.equal(normalizeEvent("grok", { reason: "session_end", lastAssistantMessage: "Bye" }, {}), undefined);
  assert.equal(normalizeEvent("grok", { reason: "end_turn", lastAssistantMessage: "Done" }, {})?.message, "Done");
});

test("marks failed agent events as time-sensitive", () => {
  const event = normalizeEvent("cursor", { status: "failed", error_message: "Build failed" }, {});
  assert(event);
  assert.equal(notificationOptions(event, "Cursor").level, "timeSensitive");
});

test("installation summary distinguishes installed, incomplete, and unselected agents", () => {
  const lines = formatInstallSummary(["codex", "deepseek"], ["codex", "claude", "deepseek"], [
    { agent: "codex", path: "/tmp/codex", changed: true },
    { agent: "deepseek", path: "/tmp/hooks", changed: true },
    { agent: "deepseek", path: "/tmp/profile", changed: false, error: "pnpm failed" },
  ], false);
  assert.match(lines.join("\n"), /Installed now: Codex/);
  assert.match(lines.join("\n"), /Incomplete or failed: DeepSeek Harness/);
  assert.match(lines.join("\n"), /Not selected: Claude Code/);
});
