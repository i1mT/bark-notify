import assert from "node:assert/strict";
import test from "node:test";
import { makePayload } from "../src/bark.js";
import { emptySendOptions } from "../src/parser.js";
import type { ResolvedConfig } from "../src/types.js";

const config: ResolvedConfig = {
  server: "https://bark.example.com",
  deviceKey: "device-key",
  group: "terminal",
  level: "active",
  archive: true,
};

test("payload uses Bark API V2 field names", () => {
  const options = { ...emptySendOptions(), message: "done", title: "Build", call: true, autoCopy: true };
  assert.deepEqual(makePayload(options, config), {
    device_key: "device-key",
    title: "Build",
    body: "done",
    level: "active",
    group: "terminal",
    call: "1",
    autoCopy: "1",
    isArchive: "1",
  });
});

test("explicit options override defaults", () => {
  const options = { ...emptySendOptions(), markdown: "**done**", level: "critical" as const, archive: false, noAction: true };
  const payload = makePayload(options, config);
  assert.equal(payload.body, "**done**");
  assert.equal(payload.markdown, "**done**");
  assert.equal(payload.level, "critical");
  assert.equal(payload.isArchive, undefined);
  assert.equal(payload.action, "none");
});
