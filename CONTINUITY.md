# CONTINUITY

## Snapshot (≤ 25 lines)
- Goal: Align the Azure VM deployment with the central `bicep-action` reusable workflow standard while keeping browser-based VS Code tunnel access from the phone as the primary workflow. (2026-03-20) [USER]
- Now: The deployable VM package now lives under `Bicep/`, `android-workstation` now calls `bicep-action@v2` through repo-local PR/apply workflows, and `azure-vm/` now serves as the GitHub-first deployment guide plus the optional local fallback helper. (2026-03-20) [CODE]
- Next: Replace the placeholder SSH public key in `Bicep/main.bicepparam`, configure GitHub secrets plus Azure federated credentials, and run the first PR `what-if` through GitHub. (2026-03-20) [ASSUMPTION]
- Open Questions: A fully supported, well-documented unattended VS Code tunnel token issuance and rotation flow for this single-user scenario remains UNCONFIRMED, so the repo still defaults to one human tunnel sign-in. (2026-03-20) [TOOL]

## Decisions
- D001 ACTIVE: Keep the phone/browser tunnel workflow as the primary UX and treat SSH only as an admin fallback. (2026-03-19) [USER] Stated explicitly in the session brief.
- D002 ACTIVE: Do not create Key Vault by default for this VM flow. (2026-03-19) [CODE] For this single-user dev/test scenario, local SSH key custody and one-time interactive tunnel sign-in are the simpler and safer default.
- D003 ACTIVE: Align this repo to the shared `bicep-action` contract with deployable infra under `/Bicep` and caller workflows under `/.github/workflows`. (2026-03-20) [CODE]

## Done (recent) (≤ 7)
- 2026-03-19 [TOOL] Read repo onboarding guidance from `.agents/.ONBOARDING.md`, `.agents/FILES.md`, and `.agents/continuity/LEDGER_RULES.md`.
- 2026-03-19 [CODE] Added first-boot bootstrap parameters, tunnel helper support, and the local fallback helper for the Azure VM flow.
- 2026-03-19 [CODE] Rewrote `azure-vm/README.md` and added `azure-vm/.INDEX.md` to document the VM automation boundary and phone workflow.
- 2026-03-20 [TOOL] Reviewed `bicep-action` reusable workflows, examples, and onboarding docs to extract the caller contract for this repo.
- 2026-03-20 [CODE] Moved the deployable Azure VM package into `/Bicep` and added `Bicep/main.bicepparam` as the canonical GitHub-used parameter file.
- 2026-03-20 [CODE] Added `/.github/workflows/pr.yml` and `/.github/workflows/deploy.yml` to call `bicep-action@v2` with the subscription-scope VM deployment.
- 2026-03-20 [CODE] Rewrote `azure-vm/README.md`, updated indexes, repointed the local fallback helper at `/Bicep`, and removed the old duplicate/generated deployment files from `azure-vm/`.

## Working set (≤ 12 paths)
- /Bicep/.INDEX.md
- /Bicep/main.bicep
- /Bicep/main.bicepparam
- /Bicep/modules/dev-vm-stack.bicep
- /Bicep/scripts/bootstrap-vm.sh
- /.github/workflows/pr.yml
- /.github/workflows/deploy.yml
- /azure-vm/README.md
- /azure-vm/.INDEX.md
- /azure-vm/scripts/prepare-local-deployment.sh
- /README.md
- /CONTINUITY.md

## Receipts (last 10–20)
- 2026-03-19T13:25Z [TOOL] `git rev-parse --show-toplevel` resolved repo root to `martinjensen225/android-workstation`.
- 2026-03-19T13:25Z [TOOL] `list_mcp_resources` and `list_mcp_resource_templates` returned no configured resources/templates.
- 2026-03-19T13:26Z [TOOL] Read official VS Code Remote Tunnels docs and Azure VM custom data docs via web.
- 2026-03-19T14:25Z [TOOL] Inspected local VS Code CLI help and confirmed support for `code tunnel user login --provider`, `--access-token`, and `--refresh-token`.
- 2026-03-19T14:40Z [TOOL] Validation environment lacked a runnable local Bicep CLI and local bash shell; final verification relied on source review plus `git diff --check`.
- 2026-03-20T08:16Z [TOOL] Compared this repo against `bicep-action` reusable workflows, example caller files, and onboarding docs to extract the required GitHub contract.
- 2026-03-20T08:17Z [CODE] Added `/Bicep` and `/.github/workflows`, moved the deployable VM package to the standard layout, and rewrote the deployment docs around GitHub Actions.
- 2026-03-20T08:18Z [TOOL] `git diff --check` passed; local `az bicep build` and `build-params` could not complete because the bundled CLI attempted a network version check blocked by the session.
