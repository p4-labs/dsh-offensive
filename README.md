# dsh-offensive

A [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (dsh) bundle that ports
[offensive-claude](https://github.com/hypnguyen1209/offensive-claude) — a spec-driven offensive
security framework — into dsh as a self-contained plugin.

**Authorized security testing only.** See [TERMS.md](TERMS.md).

## What you get

- **Offensive agent preset** — appears in the preset picker; an attacker-perspective persona
  with kill-chain engagement flow, scope/finding/OPSEC discipline
- **39 skills** (recon-osint, web-pentest, exploit-development, active-directory-attack,
  cloud-security, ...) loadable via the `skill` tool, plus 8 agent playbooks
- **18 engagement commands** — `/engage-init`, `/engage-scope`, `/engage-recon`, ...,
  `/engage-report` (Claude Code's `engage.*` commands, converted)
- **SessionStart / SubagentStart hooks** injecting the framework's skill-invocation
  dispatcher (via `dsh-hooks-claude-code`)
- The framework's Python tooling (`engine/`, `skills/*/scripts/`, templates, workflows)

## Install

```bash
dsh plugin --profile web add <dsh-offensive.tar.gz>
# then restart dsh, create a new session, pick the "Offensive" preset
```

Requires dsh web profile (tested on 0.1.5-rc.x).

## Layout

```
modes/offensive/            framework root (self-contained)
├── preset.yml              preset manifest
├── agent.cordis.yml        preset composition (paths resolved via baseUrl)
├── home/AGENTS.md          workspace instructions (scoped to this preset)
├── hooks/                  SessionStart/SubagentStart dispatcher hooks
├── skills/                 39 skill bundles + 8 agents + 18 engage-* commands
└── engine/ templates/ workflows/ presets/ TERMS.md
lib/index.js                bundle entry: registers the preset root and mounts
                            the hook bridge (paths from import.meta.url)
```

## Upstream sync

Content is vendored from the upstream repo with small dsh-compatibility patches
(hook JSON emission shape, frontmatter fence fixes, `engage.*` → `engage-*`
conversion). To update: `./scripts/sync-upstream.sh` — see [UPDATE.md](UPDATE.md).

## Credits

All framework content © [hypnguyen1209/offensive-claude](https://github.com/hypnguyen1209/offensive-claude) (MIT).
This repository is only the dsh packaging layer.
