import assert from "node:assert/strict";
import test from "node:test";
import { parseArguments } from "../src/parser.js";

test("short send syntax remains the default", () => {
  const command = parseArguments(["-t", "Build", "Finished", "--level", "timeSensitive"]);
  assert.equal(command.kind, "send");
  if (command.kind !== "send") return;
  assert.equal(command.options.title, "Build");
  assert.equal(command.options.message, "Finished");
  assert.equal(command.options.level, "timeSensitive");
});

test("run separates notification options from the command", () => {
  const command = parseArguments(["run", "-g", "deploy", "--", "sh", "-c", "exit 3"]);
  assert.equal(command.kind, "run");
  if (command.kind !== "run") return;
  assert.deepEqual(command.command, ["sh", "-c", "exit 3"]);
  assert.equal(command.options.group, "deploy");
});

test("invalid levels are rejected", () => {
  assert.throws(() => parseArguments(["hello", "--level", "urgent"]), /Invalid level/);
});
