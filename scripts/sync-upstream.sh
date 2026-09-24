#!/usr/bin/env bash
# Sync dsh-offensive with upstream offensive-claude, repack, and reinstall.
#
#   ./scripts/sync-upstream.sh              # sync if needed, bump, pack, install locally
#   PROFILE=<name> ./scripts/sync-upstream.sh # install into another profile
#
# Cheap path first: compares the upstream HEAD commit against `upstream.lock`.
# If upstream hasn't moved, only the patch version is bumped, re-packed, and
# reinstalled. All work is done from a temp clone that is removed afterwards.
# Restart dsh afterwards to load the new bundle.
#
# Everything upstream-derived is REGENERATED here — keep local customizations
# out of modes/offensive/{skills,hooks,home,engine,templates,workflows,presets}
# or they will be overwritten; add patch steps at the bottom instead.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="$ROOT/modes/offensive"
LOCK="$ROOT/upstream.lock"
REPO="https://github.com/hypnguyen1209/offensive-claude"

remote_head="$(git ls-remote "$REPO" HEAD | cut -f1)"
if [ -f "$LOCK" ] && [ "$(cat "$LOCK")" = "$remote_head" ]; then
  echo ">> already up to date (${remote_head:0:7})"
  exit 0
fi
echo ">> upstream moved: $(cat "$LOCK" 2>/dev/null | cut -c1-7 || echo none) -> ${remote_head:0:7}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone --depth 1 "$REPO" "$TMP/upstream" --quiet
UPSTREAM="$TMP/upstream"

# ── content: skills, framework dirs, hooks ───────────────────────────────────
rsync -a --delete "$UPSTREAM/skills/"     "$MODE/skills/"
rsync -a --delete "$UPSTREAM/engine/"     "$MODE/engine/"
rsync -a --delete "$UPSTREAM/templates/"  "$MODE/templates/"
rsync -a --delete "$UPSTREAM/workflows/"  "$MODE/workflows/"
rsync -a --delete "$UPSTREAM/presets/"    "$MODE/presets/"
cp "$UPSTREAM/TERMS.md" "$MODE/TERMS.md"
mkdir -p "$MODE/hooks"
cp "$UPSTREAM"/hooks/{hooks.json,run-hook.cmd,session-start,subagent-start} "$MODE/hooks/"
chmod +x "$MODE/hooks"/{run-hook.cmd,session-start,subagent-start}

# agents ship as flat skill-catalog files alongside the skill bundles
rsync -a "$UPSTREAM/agents/" "$MODE/skills/" --include='*.md' --exclude='*'

# ── dsh-compatibility patches ────────────────────────────────────────────────
python3 - "$MODE" "$UPSTREAM" <<'PYEOF'
import pathlib, re, sys
mode, upstream = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])

# Hooks: dsh's hook bridge only consumes hookSpecificOutput.additionalContext
# and never sets CLAUDE_PLUGIN_ROOT as an env var — collapse the multi-platform
# emission to the Claude Code shape, and announce the runtime framework root.
def patch_hook(name, event, var):
    hook = mode/'hooks'/name
    t = hook.read_text()
    t = re.sub(
        r'# Emit only the field the current platform consumes.*?^fi\n',
        '# dsh: always emit the hookSpecificOutput form the dsh hook bridge consumes.\n'
        f'printf \'{{\\n  "hookSpecificOutput": {{\\n    "hookEventName": "{event}",\\n    '
        f'"additionalContext": "%s"\\n  }}\\n}}\\n\' "${var}"\n',
        t, flags=re.S | re.M)
    hook.write_text(t)

patch_hook('session-start', 'SessionStart', 'session_context')
patch_hook('subagent-start', 'SubagentStart', 'reminder_escaped')

sh = mode/'hooks/session-start'
t = sh.read_text()
t = t.replace(
    'You are operating offensive-claude, an AUTHORIZED offensive-security framework.\\n\\n',
    'You are operating offensive-claude, an AUTHORIZED offensive-security framework.\\n\\nFramework root (resolve all framework-relative paths against it): ${PLUGIN_ROOT}\\n\\n')
sh.write_text(t)

# Some SKILL.md close frontmatter with an indented `  ---` — dsh rejects it.
for skill in (mode/'skills').glob('*/SKILL.md'):
    t = skill.read_text()
    fixed = t.replace('\n  ---\n', '\n---\n', 1)
    if fixed != t:
        skill.write_text(fixed)

# Claude Code commands -> flat dsh skills (engage.init -> engage-init)
for f in sorted((upstream/'commands').glob('*.md')):
    text = f.read_text()
    m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    fm, body = (m.group(1), text[m.end():]) if m else ('', text)
    d = re.search(r'^description:\s*(.+)$', fm, re.M)
    desc = d.group(1).strip() if d else f'offensive-claude command {f.stem}'
    name = f.stem.replace('.', '-')
    header = (f"---\nname: {name}\ndescription: {desc}\n"
              f"metadata:\n  source: offensive-claude/commands/{f.name}\n---\n\n"
              "> Framework resources (workflows/, templates/, engine/, presets/) live at the "
              "**framework root** — named in the SessionStart context and derivable from any "
              "loaded skill's resource base path. Resolve relative paths in this command against it.\n\n")
    (mode/'skills'/f"{name}.md").write_text(header + body)

# AGENTS.md from upstream CLAUDE.md (relative paths, dsh wording)
text = (upstream/'CLAUDE.md').read_text().replace('/engage.', '/engage-')
header = """# Security Research & Offensive Operations Config (dsh-offensive bundle)

> Ported from [offensive-claude](https://github.com/hypnguyen1209/offensive-claude).
> The SessionStart context names the **framework root** (an absolute path) — resolve every
> relative path below (`skills/`, `engine/`, `templates/`, `workflows/`, `presets/`, `TERMS.md`)
> against that root. Loading any skill with the `skill` tool also reveals the root via its
> resource base path.
> Skills/agents live in the dsh skill catalog of this preset — load a skill with the `skill`
> tool before acting on it; users can invoke one with `/<name>`.
> Engagement commands use dash names: `/engage-init`, `/engage-scope`, ...

"""
(mode/'home').mkdir(exist_ok=True)
(mode/'home/AGENTS.md').write_text(header + text.split('\n', 1)[1])
PYEOF

echo "$remote_head" > "$LOCK"

# ── always bump patch version, pack, install ─────────────────────────────────
cd "$ROOT"
VERSION=$(python3 -c "
import json
p = json.load(open('package.json'))
major, minor, patch = (p['version'].split('-')[0].split('.') + ['0'])[:3]
p['version'] = f'{major}.{minor}.{int(patch) + 1}'
json.dump(p, open('package.json', 'w'), indent=2)
print(p['version'])
")
echo ">> version $VERSION"
TGZ=$(npm pack 2>/dev/null | tail -1)
dsh plugin --profile "${PROFILE:-web}" add "file:$ROOT/$TGZ"
echo ">> done — restart dsh to load dsh-offensive $VERSION"
