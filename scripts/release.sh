#!/usr/bin/env bash
# Publish a new dsh-offensive release.
#
#   ./scripts/release.sh
#
# Does one thing and does it well: after you run ./scripts/sync-upstream.sh
# (or not), this script commits the current state, tags it, pushes, and
# creates a GitHub Release with the tarball named `dsh-offensive.tar.gz`.
#
# Requires git + a configured remote.
# If `gh` (GitHub CLI) is authenticated, the release is created automatically.
# Otherwise the script prints the exact `gh release create` command to run.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repo. Run: git init && git add -A && git commit -m init" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "warning: there are uncommitted changes; they will be included in this release." >&2
fi

VERSION=$(node -p "require('./package.json').version")
TGZ="dsh-offensive-${VERSION}.tgz"
if [ ! -f "$TGZ" ]; then
  echo "error: $TGZ not found. Run ./scripts/sync-upstream.sh first." >&2
  exit 1
fi

cp "$TGZ" "dsh-offensive.tar.gz"

# Use the package README body as release notes
RELEASE_NOTES="$ROOT/RELEASE_NOTES.md"
if [ ! -f "$RELEASE_NOTES" ]; then
  cat > "$RELEASE_NOTES" <<EOF
Release dsh-offensive ${VERSION}.
- Upstream sync via scripts/sync-upstream.sh.
- Install with:
    dsh plugin --profile web add https://github.com/<you>/dsh-offensive/releases/latest/download/dsh-offensive.tar.gz
EOF
fi

git add -A
git commit -m "dsh-offensive ${VERSION}" || true
git tag -a "v${VERSION}" -m "dsh-offensive ${VERSION}" || true
git push origin "$(git branch --show-current)" || {
  echo "error: git push failed — set your remote first." >&2
  exit 1
}
git push origin "v${VERSION}" || true

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh release create "v${VERSION}" "dsh-offensive.tar.gz" --title "dsh-offensive ${VERSION}" --notes-file "$RELEASE_NOTES"
  echo ">> released v${VERSION}"
else
  echo ">> git tag v${VERSION} pushed."
  echo ">> Now create the release and upload the tarball from the GitHub UI, or install gh and run:"
  echo "   gh release create v${VERSION} dsh-offensive.tar.gz --title 'dsh-offensive ${VERSION}' --notes-file ${RELEASE_NOTES}"
fi
