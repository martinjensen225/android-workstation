# Azure VM Deployment Guide

This repo now treats GitHub Actions as the primary deployment path for the Azure VM that hosts the VS Code tunnel. The phone remains the browser client, and SSH stays a temporary admin fallback.

The standard deployment layout now lives under [`../Bicep/`](../Bicep/.INDEX.md), and this folder keeps the human-facing deployment guide plus the optional local fallback helper.

## What Stays the Same

The workload design is unchanged:

- Ubuntu VM on Azure
- subscription-scope deployment that creates its own resource group
- first-boot bootstrap through VM `customData`
- `outboundConnectivityMode = 'vmPublicIp'`
- no inbound SSH rule by default
- browser-based VS Code on the phone as the primary workflow
- one-time human tunnel sign-in after deployment

## Standard Repo Layout

- [`../Bicep/main.bicep`](../Bicep/main.bicep): Subscription-scope entry point.
- [`../Bicep/main.bicepparam`](../Bicep/main.bicepparam): Canonical parameter file used by GitHub Actions.
- [`../Bicep/modules/dev-vm-stack.bicep`](../Bicep/modules/dev-vm-stack.bicep): Resource-group-scoped VM stack.
- [`../Bicep/scripts/bootstrap-vm.sh`](../Bicep/scripts/bootstrap-vm.sh): First-boot bootstrap payload injected through `customData`.
- [`../.github/workflows/pr.yml`](../.github/workflows/pr.yml): Reusable PR `what-if` caller.
- [`../.github/workflows/deploy.yml`](../.github/workflows/deploy.yml): Reusable apply caller with `workflow_dispatch`.
- [`scripts/prepare-local-deployment.sh`](./scripts/prepare-local-deployment.sh): Optional local fallback helper.

## GitHub Deployment Flow

This repo now follows the standard `bicep-action` pattern:

1. Open a pull request that changes files under `Bicep/`.
2. The PR workflow compiles the Bicep, lints the `Bicep/` folder, runs Azure `what-if`, and updates a single PR comment with the plan.
3. Review the PR and merge to `main`.
4. The deploy workflow runs Azure `create` against the merged commit.
5. If you need a manual deploy from the GitHub portal, run `.github/workflows/deploy.yml` with `workflow_dispatch`.

No GitHub Environment approval gate is used in the default path because this repo now follows the central `bicep-action` standard directly.

## Required Manual Setup

Before the first GitHub run, complete these steps:

1. Replace the placeholder `adminSshPublicKey` in [`../Bicep/main.bicepparam`](../Bicep/main.bicepparam) with your real SSH public key.
2. Add these GitHub Actions secrets in the `android-workstation` repo:
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_CLIENT_ID_APPLY`
3. In Azure, configure federated credentials for the shared identity:
   - `repo:martinjensen225/android-workstation:pull_request`
   - `repo:martinjensen225/android-workstation:ref:refs/heads/main`
4. Grant that identity Azure permissions at subscription scope for the deployment target. If you later enable budget creation in `main.bicepparam`, make sure the identity can also write the budget resource.

The tracked parameter file currently ships with `enableBudget = false` so the GitHub deployment path does not depend on budget-contact emails by default.

## One-Time Tunnel Registration

The VM bootstrap is automated, but the tunnel still needs one human sign-in after the machine is created.

Recommended GitHub-centric flow:

1. Temporarily set `adminSshSourceCidrs` in [`../Bicep/main.bicepparam`](../Bicep/main.bicepparam) to your current public IP `/32`.
2. Open a PR and merge it so the workflow updates the NSG.
3. SSH in and run the registration helper on the VM:

   ```bash
   ssh -i ~/.ssh/id_ed25519_android_workstation_vm martin@<vm-public-ip>
   android-workstation-tunnel-register microsoft
   ```

4. Remove the temporary CIDR in a follow-up PR so SSH returns to the secure default.

If you prefer GitHub auth instead of Microsoft auth, run:

```bash
android-workstation-tunnel-register github
```

After registration, the tunnel service should come back automatically on later boots.

## Optional Local Fallback

GitHub Actions is the primary deployment path. The local helper exists only for fallback use when you intentionally want a local `what-if` or local apply.

Run:

```bash
cd azure-vm/scripts
chmod +x prepare-local-deployment.sh
./prepare-local-deployment.sh
```

That helper:

- creates or reuses `~/.ssh/id_ed25519_android_workstation_vm`
- copies `Bicep/main.bicepparam` to an ignored local file
- writes the generated public key into that local file
- prints the local `what-if` and `create` commands to run next

The private key stays local. It is never uploaded by the template.

## Operational Notes

- `customData` is a first-boot mechanism. Updating the bootstrap script later does not automatically re-run it on an existing VM.
- If the bootstrap script fails, Azure can still show the VM as provisioned. Check the bootstrap log if needed.
- The secure default remains `adminSshSourceCidrs = []`, with SSH opened only when you need temporary admin access.
- Remote Tunnels remain single-user oriented. The same Microsoft or GitHub account should be used on both sides.
