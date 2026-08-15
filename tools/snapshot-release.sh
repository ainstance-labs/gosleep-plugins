#!/usr/bin/env bash
# snapshot-release.sh — re-snapshot a named bundle's skills from the authoritative
# global ~/.claude/skills tree into this repo, then print the diff and remind the
# owner to bump the bundle's plugin.json version.
#
# Direction of flow is READ-ONLY from global into this repo:
#   ~/.claude/skills/<skill>/  --rsync-->  <repo>/<bundle>/skills/<skill>/
#
# GUARDS
#   * Refuses to run outside this repo tree (never writes to ~/.claude/**).
#   * Refuses an unknown bundle name.
#   * Prints (does not commit) — bump + commit + `claude plugin tag` are owner steps.
#
# USAGE
#   tools/snapshot-release.sh <bundle-name>
#   tools/snapshot-release.sh --all
#
# Named bundles + their skill lists mirror the marketplace entries in
# .claude-plugin/marketplace.json.

set -euo pipefail

# Resolve the repo root as the directory that contains this script's parent.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Guard: the repo root must contain the marketplace manifest. Refuse otherwise —
# this protects against being copied elsewhere and run in a foreign tree.
if [ ! -f "$REPO_ROOT/.claude-plugin/marketplace.json" ]; then
  echo "error: $REPO_ROOT does not look like the gosleep-plugins repo (no .claude-plugin/marketplace.json)" >&2
  exit 2
fi

GLOBAL_SKILLS="$HOME/.claude/skills"
if [ ! -d "$GLOBAL_SKILLS" ]; then
  echo "error: global skills tree not found at $GLOBAL_SKILLS" >&2
  exit 2
fi

# Bundle definitions — keep in sync with .claude-plugin/marketplace.json.
delivery_skills=(delivery-workflow using-jira writing-prds handoff)
orchestration_skills=(orchestrating-delivery-agents tmux-agents-orchestration remote-control)
evals_skills=(verifier-skeptic agentic-scenario-runner agentic-report-creator efficient-agent-evals extra-usage)

resolve_bundle() {
  case "$1" in
    gosleep-delivery)      printf '%s\n' "${delivery_skills[@]}" ;;
    gosleep-orchestration) printf '%s\n' "${orchestration_skills[@]}" ;;
    gosleep-evals)         printf '%s\n' "${evals_skills[@]}" ;;
    *) return 1 ;;
  esac
}

snapshot_bundle() {
  local bundle="$1"
  local skills
  if ! skills="$(resolve_bundle "$bundle")"; then
    echo "error: unknown bundle '$bundle'" >&2
    echo "known bundles: gosleep-delivery gosleep-orchestration gosleep-evals" >&2
    return 2
  fi

  local target_root="$REPO_ROOT/$bundle/skills"
  if [ ! -d "$target_root" ]; then
    echo "error: target dir $target_root missing (expected repo layout)" >&2
    return 2
  fi

  # Extra guard: never write outside the repo.
  case "$target_root" in
    "$REPO_ROOT"/*) : ;;
    *) echo "error: refusing to write outside repo ($target_root)" >&2; return 2 ;;
  esac

  echo "=== snapshotting bundle: $bundle ==="
  local skill
  while IFS= read -r skill; do
    local src="$GLOBAL_SKILLS/$skill/"
    local dst="$target_root/$skill/"
    if [ ! -d "$src" ]; then
      echo "  skip $skill (not present in global)" >&2
      continue
    fi
    mkdir -p "$dst"
    # READ-ONLY from global into repo: --delete keeps the mirror clean of removed files.
    rsync -a --delete --exclude=".DS_Store" "$src" "$dst"
    echo "  rsynced $skill"
  done <<< "$skills"

  echo
  echo "--- diff against HEAD for $bundle ---"
  (cd "$REPO_ROOT" && git diff --stat -- "$bundle/skills/" || true)
  echo
  echo "REMINDER: if anything changed, bump $bundle/.claude-plugin/plugin.json version"
  echo "          (patch for tweaks, minor for content additions), commit, then:"
  echo "            claude plugin tag ./$bundle --push"
  echo
}

main() {
  if [ $# -eq 0 ]; then
    echo "usage: $0 <bundle-name>|--all" >&2
    return 2
  fi

  if [ "$1" = "--all" ]; then
    snapshot_bundle gosleep-delivery
    snapshot_bundle gosleep-orchestration
    snapshot_bundle gosleep-evals
  else
    snapshot_bundle "$1"
  fi
}

main "$@"
