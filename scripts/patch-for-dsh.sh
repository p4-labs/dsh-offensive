#!/usr/bin/env bash
# Apply dsh-compatibility patches after manually syncing upstream content.
#
#   ./scripts/patch-for-dsh.sh
#
# Run this after copying upstream files into modes/offensive/. It performs
# string replacements so the vendored content behaves correctly in dsh instead
# of assuming Claude Code.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="$ROOT/modes/offensive"

echo ">> patching CLAUDE.md -> AGENTS.md"
find "$MODE" -type f \( -name "*.md" -o -name "*.py" \) \
  -exec sed -i '' 's/CLAUDE\.md/AGENTS.md/g' {} +

echo ">> patching ~/.claude -> ~/.dsh"
find "$MODE" -type f \( -name "*.md" -o -name "*.py" \) \
  -exec sed -i '' 's|~/.claude|~/.dsh|g' {} +

echo ">> patching \".claude\" path segments -> \".dsh\""
find "$MODE" -type f -name "*.py" \
  -exec sed -i '' 's/"\.claude"/".dsh"/g' {} +

echo ">> patching 'Claude Code' -> 'dsh' in workflow docs"
find "$MODE/workflows" -type f -name "*.md" \
  -exec sed -i '' 's/Claude Code/dsh/g' {} +

echo ">> patching Claude Desktop MCP config path -> dsh default"
find "$MODE" -type f \( -name "*.md" -o -name "*.py" \) \
  -exec sed -i '' 's|~/.config/Claude/claude_desktop_config.json|~/.dsh/mcp-config.json|g' {} +

echo ">> done. Review: git -C $ROOT diff --stat"
