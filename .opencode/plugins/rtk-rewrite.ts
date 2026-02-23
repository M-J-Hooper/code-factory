/**
 * rtk-rewrite — OpenCode plugin equivalent of the Claude Code PreToolUse:Bash hook.
 *
 * Transparently rewrites raw commands to their rtk equivalents before execution,
 * providing 60-90% token savings on dev operations.
 *
 * Mirrors the logic in hooks/rtk-rewrite.sh for Claude Code.
 */
import type { Plugin } from "@opencode-ai/plugin"

/** Strip leading env-var assignments (e.g. "FOO=bar BAZ=1 cmd ...") */
function splitEnvPrefix(cmd: string): { prefix: string; body: string } {
  const m = cmd.match(/^(?:[A-Za-z_][A-Za-z0-9_]*=[^ ]* +)+/)
  if (m) return { prefix: m[0], body: cmd.slice(m[0].length) }
  return { prefix: "", body: cmd }
}

/** Strip git global flags for subcommand matching */
function gitSubcmd(body: string): string {
  return body
    .replace(/^git\s+/, "")
    .replace(/(-C|-c)\s+\S+\s*/g, "")
    .replace(/--[a-z-]+=\S+\s*/g, "")
    .replace(/--(no-pager|no-optional-locks|bare|literal-pathspecs)\s*/g, "")
    .trimStart()
}

/** Strip docker global flags for subcommand matching */
function dockerSubcmd(body: string): string {
  return body
    .replace(/^docker\s+/, "")
    .replace(/(-H|--context|--config)\s+\S+\s*/g, "")
    .replace(/--[a-z-]+=\S+\s*/g, "")
    .trimStart()
}

/** Strip kubectl global flags for subcommand matching */
function kubectlSubcmd(body: string): string {
  return body
    .replace(/^kubectl\s+/, "")
    .replace(/(--context|--kubeconfig|--namespace|-n)\s+\S+\s*/g, "")
    .replace(/--[a-z-]+=\S+\s*/g, "")
    .trimStart()
}

function startsWithWord(s: string, word: string): boolean {
  return s === word || s.startsWith(word + " ")
}

function matchesAny(s: string, words: string[]): boolean {
  return words.some((w) => startsWithWord(s, w))
}

function rewrite(cmd: string): string | null {
  // Skip if already using rtk
  if (/^rtk\s/.test(cmd) || /\/rtk\s/.test(cmd)) return null
  // Skip heredocs
  if (cmd.includes("<<")) return null

  const { prefix, body } = splitEnvPrefix(cmd)
  const match = body // the command portion without env prefix

  // --- Git ---
  if (/^git\s/.test(match)) {
    const sub = gitSubcmd(match)
    const allowed = [
      "status", "diff", "log", "add", "commit", "push",
      "pull", "branch", "fetch", "stash", "show",
    ]
    if (matchesAny(sub, allowed)) return prefix + "rtk " + body
  }

  // --- GitHub CLI ---
  else if (/^gh\s+(pr|issue|run|api|release)(\s|$)/.test(match)) {
    return prefix + body.replace(/^gh /, "rtk gh ")
  }

  // --- Cargo ---
  else if (/^cargo\s/.test(match)) {
    const sub = match.replace(/^cargo\s+(\+\S+\s+)?/, "")
    const allowed = ["test", "build", "clippy", "check", "install", "fmt"]
    if (matchesAny(sub, allowed)) return prefix + "rtk " + body
  }

  // --- File operations ---
  else if (/^cat\s+/.test(match)) {
    return prefix + body.replace(/^cat /, "rtk read ")
  } else if (/^(rg|grep)\s+/.test(match)) {
    return prefix + body.replace(/^(rg|grep) /, "rtk grep ")
  } else if (/^ls(\s|$)/.test(match)) {
    return prefix + body.replace(/^ls/, "rtk ls")
  } else if (/^tree(\s|$)/.test(match)) {
    return prefix + body.replace(/^tree/, "rtk tree")
  } else if (/^find\s+/.test(match)) {
    return prefix + body.replace(/^find /, "rtk find ")
  } else if (/^diff\s+/.test(match)) {
    return prefix + body.replace(/^diff /, "rtk diff ")
  } else if (/^head\s+/.test(match)) {
    // head -N file → rtk read file --max-lines N
    let m = match.match(/^head\s+-(\d+)\s+(.+)$/)
    if (m) return prefix + "rtk read " + m[2] + " --max-lines " + m[1]
    m = match.match(/^head\s+--lines=(\d+)\s+(.+)$/)
    if (m) return prefix + "rtk read " + m[2] + " --max-lines " + m[1]
  }

  // --- JS/TS tooling ---
  else if (/^(pnpm\s+)?(npx\s+)?vitest(\s|$)/.test(match)) {
    return prefix + body.replace(/^(pnpm )?(npx )?vitest( run)?/, "rtk vitest run")
  } else if (/^pnpm\s+test(\s|$)/.test(match)) {
    return prefix + body.replace(/^pnpm test/, "rtk vitest run")
  } else if (/^npm\s+test(\s|$)/.test(match)) {
    return prefix + body.replace(/^npm test/, "rtk npm test")
  } else if (/^npm\s+run\s+/.test(match)) {
    return prefix + body.replace(/^npm run /, "rtk npm ")
  } else if (/^(npx\s+)?vue-tsc(\s|$)/.test(match)) {
    return prefix + body.replace(/^(npx )?vue-tsc/, "rtk tsc")
  } else if (/^pnpm\s+tsc(\s|$)/.test(match)) {
    return prefix + body.replace(/^pnpm tsc/, "rtk tsc")
  } else if (/^(npx\s+)?tsc(\s|$)/.test(match)) {
    return prefix + body.replace(/^(npx )?tsc/, "rtk tsc")
  } else if (/^pnpm\s+lint(\s|$)/.test(match)) {
    return prefix + body.replace(/^pnpm lint/, "rtk lint")
  } else if (/^(npx\s+)?eslint(\s|$)/.test(match)) {
    return prefix + body.replace(/^(npx )?eslint/, "rtk lint")
  } else if (/^(npx\s+)?prettier(\s|$)/.test(match)) {
    return prefix + body.replace(/^(npx )?prettier/, "rtk prettier")
  } else if (/^(npx\s+)?playwright(\s|$)/.test(match)) {
    return prefix + body.replace(/^(npx )?playwright/, "rtk playwright")
  } else if (/^pnpm\s+playwright(\s|$)/.test(match)) {
    return prefix + body.replace(/^pnpm playwright/, "rtk playwright")
  } else if (/^(npx\s+)?prisma(\s|$)/.test(match)) {
    return prefix + body.replace(/^(npx )?prisma/, "rtk prisma")
  }

  // --- Containers ---
  else if (/^docker\s/.test(match)) {
    if (/^docker\s+compose(\s|$)/.test(match)) {
      return prefix + body.replace(/^docker /, "rtk docker ")
    }
    const sub = dockerSubcmd(match)
    const allowed = ["ps", "images", "logs", "run", "build", "exec"]
    if (matchesAny(sub, allowed)) {
      return prefix + body.replace(/^docker /, "rtk docker ")
    }
  } else if (/^kubectl\s/.test(match)) {
    const sub = kubectlSubcmd(match)
    const allowed = ["get", "logs", "describe", "apply"]
    if (matchesAny(sub, allowed)) {
      return prefix + body.replace(/^kubectl /, "rtk kubectl ")
    }
  }

  // --- Network ---
  else if (/^curl\s+/.test(match)) {
    return prefix + body.replace(/^curl /, "rtk curl ")
  } else if (/^wget\s+/.test(match)) {
    return prefix + body.replace(/^wget /, "rtk wget ")
  }

  // --- pnpm package management ---
  else if (/^pnpm\s+(list|ls|outdated)(\s|$)/.test(match)) {
    return prefix + body.replace(/^pnpm /, "rtk pnpm ")
  }

  // --- Python tooling ---
  else if (/^pytest(\s|$)/.test(match)) {
    return prefix + body.replace(/^pytest/, "rtk pytest")
  } else if (/^python\s+-m\s+pytest(\s|$)/.test(match)) {
    return prefix + body.replace(/^python -m pytest/, "rtk pytest")
  } else if (/^ruff\s+(check|format)(\s|$)/.test(match)) {
    return prefix + body.replace(/^ruff /, "rtk ruff ")
  } else if (/^pip\s+(list|outdated|install|show)(\s|$)/.test(match)) {
    return prefix + body.replace(/^pip /, "rtk pip ")
  } else if (/^uv\s+pip\s+(list|outdated|install|show)(\s|$)/.test(match)) {
    return prefix + body.replace(/^uv pip /, "rtk pip ")
  }

  // --- Go tooling ---
  else if (/^go\s+test(\s|$)/.test(match)) {
    return prefix + body.replace(/^go test/, "rtk go test")
  } else if (/^go\s+build(\s|$)/.test(match)) {
    return prefix + body.replace(/^go build/, "rtk go build")
  } else if (/^go\s+vet(\s|$)/.test(match)) {
    return prefix + body.replace(/^go vet/, "rtk go vet")
  } else if (/^golangci-lint(\s|$)/.test(match)) {
    return prefix + body.replace(/^golangci-lint/, "rtk golangci-lint")
  }

  return null
}

export const RtkRewrite: Plugin = async ({ $ }) => {
  // Check if rtk is available at plugin load time
  try {
    await $`rtk --version`
  } catch {
    // rtk not installed — skip silently
    return {}
  }

  return {
    "tool.execute.before": async (input: any, output: any) => {
      if (input.tool !== "bash") return
      const cmd = output.args?.command
      if (typeof cmd !== "string" || !cmd) return

      const rewritten = rewrite(cmd)
      if (rewritten) {
        output.args.command = rewritten
      }
    },
  }
}
