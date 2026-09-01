import { definitionFor } from "./catalog.js";
import { detectAgents, installAgentHooks } from "./installers.js";
import { selectAgents } from "./interactive.js";
import { normalizeEvent, notificationOptions, parseAgentId, type AgentId } from "./model.js";
import type { SendOptions } from "../types.js";

export async function installCommand(agentNames: string[] | undefined, all: boolean, dryRun: boolean): Promise<number> {
  const detections = await detectAgents();
  const detected = detections.filter((item) => item.detected);
  if (detected.length === 0 && !agentNames) throw new Error("No supported coding agents were detected. Use --agents to choose one explicitly.");
  printDetections(detections);
  let ids: AgentId[];
  if (agentNames) ids = unique(agentNames.map(parseAgentId));
  else if (all) ids = detected.map((item) => item.definition.id);
  else ids = (await selectAgents(detected)).map((item) => item.definition.id);
  if (ids.length === 0) throw new Error("No coding agents were selected.");
  const results = await installAgentHooks(ids, dryRun);
  for (const result of results) {
    const label = definitionFor(result.agent).label;
    if (result.error) {
      console.error(`✗ ${label}: ${result.error} (${result.path}${result.detail ? ` · ${result.detail}` : ""})`);
      continue;
    }
    const action = dryRun ? (result.changed ? "would configure" : "already configured") : (result.changed ? "configured" : "already configured");
    console.log(`${result.changed ? "✓" : "="} ${label}: ${action} ${result.path}${result.detail ? ` (${result.detail})` : ""}`);
  }
  if (dryRun) console.log("Dry run complete; no files were changed.");
  return results.some((result) => result.error) ? 1 : 0;
}

export async function receiveCommand(
  agentName: string,
  payloadArgument: string | undefined,
  deliver: (options: SendOptions) => Promise<void>,
): Promise<number> {
  const agent = parseAgentId(agentName);
  try {
    const raw = payloadArgument ?? await readStandardInput();
    const value: unknown = raw.trim() ? JSON.parse(raw) : {};
    const event = normalizeEvent(agent, value, process.env);
    if (event) await deliver(notificationOptions(event, definitionFor(agent).label));
  } catch (error) {
    process.stderr.write(`Warning: agent hook notification failed: ${messageOf(error)}\n`);
  }
  process.stdout.write("{}\n");
  return 0;
}

function printDetections(items: Awaited<ReturnType<typeof detectAgents>>): void {
  console.log("Coding agent scan:");
  for (const item of items) {
    if (!item.detected) continue;
    const evidence = item.executable ?? item.evidence ?? "configuration found";
    console.log(`  ${item.configured ? "✓" : "•"} ${item.definition.label} — ${evidence}${item.configured ? " (configured)" : ""}`);
  }
}

async function readStandardInput(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  return Buffer.concat(chunks).toString("utf8");
}

function unique<T>(values: T[]): T[] { return [...new Set(values)]; }
function messageOf(error: unknown): string { return error instanceof Error ? error.message : String(error); }
