## Repo onboarding

- At the beginning of each agent session, the agent MUST perform the onboarding procedure by reading the [.ONBOARDING.md](.agents/.ONBOARDING.md) file.

## Continuity ledger

- Resolve repo root (use `git rev-parse --show-toplevel` when available).
- Read <REPO_ROOT>/CONTINUITY.md before making edits.
- If CONTINUITY.md is missing, create it from .agents/templates/CONTINUITY.TEMPLATE.md.
- Keep it short: Snapshot ≤ 25 lines; Done ≤ 7 bullets; Working set ≤ 12 paths; Receipts keep last 10–20 items.

## Documentation indexing (directory routing)

- Each docs directory should contain a `.INDEX.md` with links to the most relevant child docs.
- When creating, renaming, moving, or deleting a doc in a directory:
  - Update that directory’s `.INDEX.md` in the same change.
  - If the directory has a `.SUMMARY.md`, refresh it when the directory’s purpose changes.
- Keep `.INDEX.md` short:
  - Prefer links + one-line descriptions.
  - Group by topic; stable ordering.
- Prefer the closest `.INDEX.md` in the area being changed.
- If none exists, use directory README/overview docs, then create `.INDEX.md` when adding multiple docs.
- Template can be found in .agents/templates/INDEX.TEMPLATE.md.

## Repo policies

- Never run direct deployment code. For example never run Bicep deployment commands without what-if. Changes in cloud environment should never happen from an agent.