import { basename } from "node:path";
import { createHash } from "node:crypto";
import { CliError, type SendOptions } from "../types.js";

export const agentIds = ["codex", "claude", "grok", "cursor", "gemini", "opencode", "copilot", "deepseek"] as const;
export type AgentId = (typeof agentIds)[number];

export interface AgentDefinition {
  id: AgentId;
  label: string;
  commands: string[];
  configDescription: string;
}

export interface DetectionResult {
  definition: AgentDefinition;
  detected: boolean;
  executable?: string;
  evidence?: string;
  configured: boolean;
}

export interface InstallResult {
  agent: AgentId;
  path: string;
  changed: boolean;
  detail?: string;
  error?: string;
}

export interface NormalizedAgentEvent {
  agent: AgentId;
  sessionId?: string;
  turnId?: string;
  cwd?: string;
  status: "completed" | "failed" | "cancelled";
  message: string;
}

export function parseAgentId(value: string): AgentId {
  if ((agentIds as readonly string[]).includes(value)) return value as AgentId;
  throw new CliError(`Unsupported coding agent: ${value}. Supported agents: ${agentIds.join(", ")}`);
}

export function normalizeEvent(agent: AgentId, value: unknown, environment: NodeJS.ProcessEnv): NormalizedAgentEvent | undefined {
  const input = record(value);
  if (agent === "grok" && text(input.reason) && input.reason !== "end_turn") return undefined;
  const status = normalizeStatus(input);
  const cwd = firstText(input.cwd, input.workspaceRoot, input.workspace_root, environment.GROK_WORKSPACE_ROOT, environment.GEMINI_CWD, environment.CURSOR_PROJECT_DIR, environment.CLAUDE_PROJECT_DIR);
  const message = firstText(
    input.last_assistant_message,
    input.lastAssistantMessage,
    input.prompt_response,
    input.final_status,
    input.error_message,
    input.errorDetails,
    input.error_details,
    nestedText(input, "message", "content"),
  ) ?? fallbackMessage(agent, status, cwd);
  return {
    agent,
    status,
    message: clip(message.trim(), 4000),
    ...(cwd ? { cwd } : {}),
    ...(firstText(input.session_id, input.sessionId, input["thread-id"], environment.GROK_SESSION_ID, environment.GEMINI_SESSION_ID) ?
      { sessionId: firstText(input.session_id, input.sessionId, input["thread-id"], environment.GROK_SESSION_ID, environment.GEMINI_SESSION_ID)! } : {}),
    ...(firstText(input.turn_id, input.turnId, input.prompt_id, input.promptId, input["turn-id"]) ?
      { turnId: firstText(input.turn_id, input.turnId, input.prompt_id, input.promptId, input["turn-id"])! } : {}),
  };
}

export function notificationOptions(event: NormalizedAgentEvent, label: string): SendOptions {
  const project = event.cwd ? basename(event.cwd) : "Coding task";
  const statusText = event.status === "completed" ? "任务完成" : event.status === "cancelled" ? "任务取消" : "任务失败";
  const identity = event.turnId ? [event.agent, event.sessionId, event.turnId, event.status].filter(Boolean).join(":") : undefined;
  return {
    title: `${label} · ${project} · ${statusText}`,
    message: event.message,
    group: "coding-agent",
    ...(identity ? { id: createHash("sha256").update(identity).digest("hex").slice(0, 32) } : {}),
    ...(event.status === "failed" ? { level: "timeSensitive" as const } : {}),
    call: false,
    autoCopy: false,
    noAction: false,
    quiet: true,
  };
}

function normalizeStatus(input: Record<string, unknown>): NormalizedAgentEvent["status"] {
  const raw = firstText(input.status, input.reason, input.error, input.error_message)?.toLowerCase() ?? "";
  if (["aborted", "abort", "cancelled", "canceled", "user_exit", "user_interrupt"].some((item) => raw.includes(item))) return "cancelled";
  if (["error", "failed", "failure", "timeout", "rate_limit"].some((item) => raw.includes(item))) return "failed";
  return "completed";
}

function fallbackMessage(agent: AgentId, status: NormalizedAgentEvent["status"], cwd: string | undefined): string {
  const action = status === "completed" ? "已经完成了当前任务。" : status === "cancelled" ? "当前任务已经取消。" : "当前任务执行失败。";
  return cwd ? `${action}\n目录：${cwd}` : action;
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function text(value: unknown): string | undefined { return typeof value === "string" && value.trim() ? value : undefined; }
function firstText(...values: unknown[]): string | undefined { return values.map(text).find(Boolean); }
function nestedText(input: Record<string, unknown>, outer: string, inner: string): string | undefined { return text(record(input[outer])[inner]); }
function clip(value: string, maximum: number): string { return value.length <= maximum ? value : `${value.slice(0, maximum - 1)}…`; }
