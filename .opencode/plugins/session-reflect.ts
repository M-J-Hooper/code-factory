/**
 * session-reflect — OpenCode plugin equivalent of the Claude Code Stop hook.
 *
 * Fires the memory-extractor agent on `session.idle` to capture session
 * learnings and update knowledge files (AGENTS.md, MEMORY.md, CLAUDE.md).
 *
 * Rate-limited: skips extraction if the last run was < 2 minutes ago.
 */
import type { Plugin } from "@opencode-ai/plugin"

let lastRunMs = 0
const COOLDOWN_MS = 2 * 60 * 1000 // 2 minutes

const REFLECT_PROMPT =
  "Analyze this session for actionable learnings. " +
  "Extract corrections, conventions, patterns, and gotchas. " +
  "Score confidence per learning. " +
  "High confidence (>=0.8): auto-apply to the target knowledge file. " +
  "Medium confidence (0.5-0.79): append to pending-learnings.md. " +
  "Low confidence (<0.5): discard. " +
  "Be fast, concise, and conservative."

export const SessionReflect: Plugin = async ({ client }) => {
  return {
    event: async ({ event }) => {
      if (event.type !== "session.idle") return

      const now = Date.now()
      if (now - lastRunMs < COOLDOWN_MS) return
      lastRunMs = now

      try {
        const sessionId = event.properties?.sessionId
        if (!sessionId) return

        // Send a prompt to the current session using the memory-extractor
        // agent. The agent definition lives at
        // ~/.config/opencode/agents/memory-extractor.md (synced by sync-opencode.sh).
        await client.session.prompt({
          path: { id: sessionId },
          body: {
            agent: "memory-extractor",
            parts: [{ type: "text", text: REFLECT_PROMPT }],
          },
        })
      } catch {
        // Silently ignore errors — reflection is best-effort.
        // Failing here must never block the user's workflow.
      }
    },
  }
}
