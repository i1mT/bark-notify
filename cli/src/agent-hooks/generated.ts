import type { AgentId } from "./model.js";
import { hookInvocation } from "./filesystem.js";

export const managedMarker = "Managed by BarkDesk notify agent-hook";

export function commandHandler(agent: AgentId, timeout: number): Record<string, unknown> {
  return { type: "command", command: hookInvocation(agent).command, timeout };
}

export function opencodePlugin(): string {
  const invocation = hookInvocation("opencode");
  return `// ${managedMarker}. Re-run "notify agent-hook install" to update this file.
import { spawn } from "node:child_process"

const node = ${JSON.stringify(invocation.node)}
const entry = ${JSON.stringify(invocation.entry)}
const args = ${JSON.stringify(invocation.arguments)}

export const BarkDeskNotify = async ({ client, directory }) => ({
  event: async ({ event }) => {
    if (event.type !== "session.idle") return
    let lastAssistantMessage
    try {
      const result = await client.session.messages({
        sessionID: event.properties.sessionID,
        directory,
        limit: 20,
      })
      const messages = result.data ?? []
      const assistant = [...messages].reverse().find(({ info }) => info.role === "assistant")
      lastAssistantMessage = assistant?.parts
        ?.filter((part) => part.type === "text")
        .map((part) => part.text)
        .join("\\n")
    } catch { /* A summary is optional; the completion notification still has value. */ }

    const payload = JSON.stringify({
      sessionId: event.properties.sessionID,
      cwd: directory,
      status: "completed",
      lastAssistantMessage,
    })
    await new Promise((resolve) => {
      const child = spawn(node, [entry, ...args], { stdio: ["pipe", "ignore", "ignore"] })
      const timer = setTimeout(() => child.kill(), 10_000)
      child.once("error", () => { clearTimeout(timer); resolve() })
      child.once("exit", () => { clearTimeout(timer); resolve() })
      child.stdin.on("error", () => {})
      child.stdin.end(payload)
    })
  },
})
`;
}
