## Continuity Ledger (compaction-safe, repo-scoped)

Maintain a single continuity file per repository: `<REPO_ROOT>/CONTINUITY.md`.

### Repo root resolution
At the start of each assistant turn:
1) Determine the active repo root:
   - If a file/path is referenced, use the nearest ancestor folder containing a `.git` directory.
   - Otherwise use the current working directory context and resolve its git root.
   - Use `git rev-parse --show-toplevel` when available to confirm the repo root.
2) Set `CONTINUITY_PATH = <REPO_ROOT>/CONTINUITY.md`.
3) Read `CONTINUITY_PATH` before acting.
4) If `CONTINUITY_PATH` does not exist, create it with a minimal template.

### Multi-repo turns
If the work in a single turn spans multiple repositories:
- Treat each repository independently.
- Read and update each repo’s own `CONTINUITY.md`.
- In the reply, provide a "Ledger Snapshot" per repo involved (Goal + Now + Next + Open Questions).

### Operating rule
- `CONTINUITY.md` is the canonical briefing designed to survive compaction; do not rely on earlier chat/tool output unless it's reflected there.

### Keep it bounded (anti-bloat)
- Keep `CONTINUITY.md` short and high-signal:
  - `Snapshot`: ≤ 25 lines.
  - `Done (recent)`: ≤ 7 bullets.
  - `Working set`: ≤ 12 paths.
  - `Receipts`: keep last 10–20 entries.
- If sections exceed caps, compress older items into milestone bullets with pointers (commit/PR/log path/doc path). Do not paste raw logs.

### Anti-drift rules
- Facts only, no transcripts.
- Every entry must include:
  - a date or ISO timestamp (e.g., `2026-01-13` or `2026-01-13T09:42Z`)
  - a provenance tag: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`
- If unknown, write `UNCONFIRMED` (never guess). If something changes, supersede it explicitly (don't silently rewrite history).

### Decisions and incidents
- Record durable choices in `Decisions` as ADR-lite entries (e.g., `D001 ACTIVE: …`).
- For recurring weirdness, create a small, stable incident capsule (Symptoms / Evidence pointers / Mitigation / Status).

### Plan tool vs ledger
- Use `update_plan` for short-term execution scaffolding (3–7 steps).
- Use `CONTINUITY.md` for long-running continuity ("what/why/current state"), not micro task lists.
- Keep them consistent at the intent/progress level.

### In replies
- Start with a brief "Ledger Snapshot" (Goal + Now + Next + Open Questions) for the active repo.
- Print the full ledger only when it materially changed or the user requests it.