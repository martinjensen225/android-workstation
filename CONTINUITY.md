# CONTINUITY

## Snapshot (≤ 25 lines)
- Goal: Rework `azure-vm` toward automated first-boot provisioning while keeping browser-based VS Code tunnel access from the phone as the primary workflow. (2026-03-19) [USER]
- Now: `azure-vm` now injects unattended first-boot bootstrap through VM `customData`, ships a phone-friendly local prep helper for fallback SSH key generation and parameter setup, and documents the tunnel registration step explicitly. (2026-03-19) [CODE]
- Next: Keep the current design under observation after first real deployment, especially the custom-data bootstrap logs and the tunnel registration ergonomics from the phone. (2026-03-19) [ASSUMPTION]
- Open Questions: A fully supported, well-documented unattended VS Code tunnel token issuance and rotation flow for this single-user scenario remains UNCONFIRMED, so the repo still defaults to one human tunnel sign-in. (2026-03-19) [TOOL]

## Decisions
- D001 ACTIVE: Keep the phone/browser tunnel workflow as the primary UX and treat SSH only as an admin fallback. (2026-03-19) [USER] Stated explicitly in the session brief.
- D002 ACTIVE: Do not create Key Vault by default for this VM flow. (2026-03-19) [CODE] For this single-user dev/test scenario, local SSH key custody and one-time interactive tunnel sign-in are the simpler and safer default.

## Done (recent) (≤ 7)
- 2026-03-19 [TOOL] Read repo onboarding guidance from `.agents/.ONBOARDING.md`, `.agents/FILES.md`, and `.agents/continuity/LEDGER_RULES.md`.
- 2026-03-19 [CODE] Reviewed `azure-vm/README.md`, `azure-vm/main.bicep`, `azure-vm/modules/dev-vm-stack.bicep`, `azure-vm/parameters/westeurope.example.bicepparam`, and `azure-vm/scripts/bootstrap-vm.sh`.
- 2026-03-19 [TOOL] Checked configured MCP resources and templates; none were available for Azure documentation lookup in this session.
- 2026-03-19 [CODE] Added first-boot bootstrap parameters to `azure-vm/main.bicep` and injected `scripts/bootstrap-vm.sh` into the VM via `customData` in `azure-vm/modules/dev-vm-stack.bicep`.
- 2026-03-19 [CODE] Reworked `azure-vm/scripts/bootstrap-vm.sh` to support unattended first boot, status logging, linger enablement, and a tunnel registration helper.
- 2026-03-19 [CODE] Added `azure-vm/scripts/prepare-local-deployment.sh` for local fallback SSH key generation and local parameter-file preparation.
- 2026-03-19 [CODE] Rewrote `azure-vm/README.md` and added `azure-vm/.INDEX.md` to document the new automation boundary, phone workflow, and secret-handling guidance.

## Working set (≤ 12 paths)
- /azure-vm/README.md
- /azure-vm/.INDEX.md
- /azure-vm/main.bicep
- /azure-vm/modules/dev-vm-stack.bicep
- /azure-vm/parameters/westeurope.example.bicepparam
- /azure-vm/scripts/bootstrap-vm.sh
- /azure-vm/scripts/prepare-local-deployment.sh
- /CONTINUITY.md

## Receipts (last 10–20)
- 2026-03-19T13:25Z [TOOL] `git rev-parse --show-toplevel` resolved repo root to `martinjensen225/android-workstation`.
- 2026-03-19T13:25Z [TOOL] `list_mcp_resources` and `list_mcp_resource_templates` returned no configured resources/templates.
- 2026-03-19T13:26Z [TOOL] Read official VS Code Remote Tunnels docs and Azure VM custom data docs via web.
- 2026-03-19T14:25Z [TOOL] Inspected local VS Code CLI help and confirmed support for `code tunnel user login --provider`, `--access-token`, and `--refresh-token`.
- 2026-03-19T14:40Z [TOOL] Validation environment lacked a runnable local Bicep CLI and local bash shell; final verification relied on source review plus `git diff --check`.
