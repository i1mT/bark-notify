import type { AgentDefinition, AgentId } from "./model.js";

export const agentDefinitions: AgentDefinition[] = [
  { id: "codex", label: "Codex", commands: ["codex"], configDescription: "~/.codex/hooks.json" },
  { id: "claude", label: "Claude Code", commands: ["claude"], configDescription: "~/.claude/settings.json" },
  { id: "grok", label: "Grok Build", commands: ["grok"], configDescription: "~/.grok/hooks/barkdesk-notify.json" },
  { id: "cursor", label: "Cursor", commands: ["cursor"], configDescription: "~/.cursor/hooks.json" },
  { id: "gemini", label: "Gemini CLI", commands: ["gemini"], configDescription: "~/.gemini/settings.json" },
  { id: "opencode", label: "OpenCode", commands: ["opencode"], configDescription: "~/.config/opencode/plugins/barkdesk-notify.js" },
  { id: "copilot", label: "GitHub Copilot CLI", commands: ["copilot"], configDescription: "~/.copilot/hooks/barkdesk-notify.json" },
  { id: "deepseek", label: "DeepSeek Harness", commands: ["dsh"], configDescription: "$DSH_HOME profiles" },
];

export function definitionFor(id: AgentId): AgentDefinition { return agentDefinitions.find((item) => item.id === id)!; }
