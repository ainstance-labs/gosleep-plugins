# gosleep-plugins

Versioned Claude Code plugin marketplace for the gosleep harness program. Wraps the
owner's 12 authored skills as three thematic plugin bundles so they carry semver, are
installable through the standard `claude plugin` flow, and gain the provenance the loose
global `~/.claude/skills/` tree cannot.

- Strategy source of truth: `gosleep/docs/reports/plugin-migration-research-2026-08-15/strategy.md`.
- Owner-approved packaging (D1/D2): three thematic bundles named below.
- Owner-approved marketplace repo (D3/D4): this repo, `ainstance-labs/gosleep-plugins`.

The bundles are a **snapshot mirror** of the authoritative global skills at
`~/.claude/skills/`. Sync direction is always **global → this repo**, owner-commanded.
This repo is never edited into the global copies.

## Bundle map (12 skills, 3 plugins)

| Plugin | Version | Skills |
|---|---|---|
| [`gosleep-delivery`](./gosleep-delivery) | 0.1.0 | delivery-workflow, using-jira, writing-prds, handoff |
| [`gosleep-orchestration`](./gosleep-orchestration) | 0.1.0 | orchestrating-delivery-agents, tmux-agents-orchestration, remote-control |
| [`gosleep-evals`](./gosleep-evals) | 0.1.0 | verifier-skeptic, agentic-scenario-runner, agentic-report-creator, efficient-agent-evals, extra-usage |

After install, skills are invoked namespaced — e.g. `gosleep-delivery:handoff`,
`gosleep-orchestration:remote-control`, `gosleep-evals:verifier-skeptic`.

## Repository layout

```
.claude-plugin/marketplace.json          # 3 plugin entries, relative-path sources
gosleep-delivery/
  .claude-plugin/plugin.json             # name, version 0.1.0, description, author
  skills/<skill-name>/…                  # rsynced from ~/.claude/skills/<name>/
gosleep-orchestration/
  .claude-plugin/plugin.json
  skills/<skill-name>/…
gosleep-evals/
  .claude-plugin/plugin.json
  skills/<skill-name>/…
tools/snapshot-release.sh                # owner-run helper: re-snapshot one bundle
README.md
```

`version` lives only in each `plugin.json` — never also in the marketplace entry
(the manifest wins silently and would mask a bumped marketplace field — documented
plugin-architecture footgun).

## Standard flow (edit → release → update)

Interim model — global `~/.claude/skills/` is the authoritative editable surface, this
repo is a **downstream snapshot mirror**:

1. **Edit the skill** in `~/.claude/skills/<name>/SKILL.md` (unchanged practice).
2. **Snapshot into this repo** for the affected bundle:
   ```sh
   ./tools/snapshot-release.sh gosleep-delivery
   ```
   The helper rsyncs `~/.claude/skills/<skill>` → `<bundle>/skills/<skill>` (READ direction
   global → repo), prints the diff, and reminds you to bump the version.
3. **Bump `plugin.json` version** for the affected bundle (semver — patch for tweaks,
   minor for content additions, major reserved for the far-future flip).
4. **Commit + push** to `main` of this repo.
5. **Tag the release** with the first-party primitive:
   ```sh
   claude plugin tag ./gosleep-delivery --push
   ```
   Creates a `gosleep-delivery--v0.1.1` git tag and cross-validates the marketplace entry.
6. **Consumers pick up the new version** on next `claude plugin update <name>` (restart
   required to apply — auto-update is intentionally not relied on).

## Provenance

- **Source-side** ("what changed between snapshots"): the git history of this repo.
  `git log --follow gosleep-delivery/skills/handoff/SKILL.md` answers the diff question
  between any two release tags.
- **Deployed-side** ("what is live where"): `~/.claude/plugins/installed_plugins.json`,
  written by Claude Code itself on every install/update — version, timestamps, commit SHA,
  scope, versioned install path. Never edited by this repo.
- **Honest limitation** — the interim (snapshot-mirror) model captures the cumulative
  diff since the previous snapshot, not per-edit author/reason. Per-edit attribution
  becomes possible only after the far-future source-of-truth inversion described in the
  gosleep strategy doc, section 3B.

## Snapshot provenance note

- **Snapshot source:** the global authoritative copies at `~/.claude/skills/` (READ-ONLY
  during snapshot).
- **Snapshot date:** 2026-08-15.
- **Strategy reference:** `gosleep/docs/reports/plugin-migration-research-2026-08-15/strategy.md`
  (sections 3A "Interim model", 3A.1 "Three thematic bundles", 3A.2 "Dedicated private repo",
  and 4A-G "Global-scope migration sub-plan G1–G4").

## Safety rules baked into this repo

- Sync direction is one-way: `~/.claude/skills/` → this repo. The `tools/snapshot-release.sh`
  helper refuses to write outside this repo tree and never writes into `~/.claude/**`.
- `version` is defined only in `plugin.json` per bundle, never in the marketplace entry —
  avoids the dual-definition footgun.
- Bundles are installed by the owner through the standard `claude plugin marketplace add`
  + `claude plugin install` flow. This repo does not install itself into anyone's Claude
  Code config.

## Local load test (no install, no ~/.claude write)

From any directory OUTSIDE both this repo and the gosleep repo:

```sh
claude --plugin-dir /path/to/gosleep-plugins/gosleep-delivery \
       --plugin-dir /path/to/gosleep-plugins/gosleep-orchestration \
       --plugin-dir /path/to/gosleep-plugins/gosleep-evals \
       -p "list available skills"
```

`--plugin-dir` loads a plugin for one session only and does not touch
`~/.claude/plugins/installed_plugins.json`.
