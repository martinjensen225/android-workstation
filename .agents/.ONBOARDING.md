## Session init checklist

The agent MUST perform the following actions when performing onboarding:

1. Identify repo root. Treat the nearest ancestor containing `.git` as the repo root. Use `git rev-parse --show-toplevel` when available.
2. Read the agent's documentation on [special files](FILES.md)
3. Read the agents' documentation on [Continuity ledger](continuity\LEDGER_RULES.md)
4. Read CONTINUITY.md if present (create from template if missing).