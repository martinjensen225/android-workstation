# Azure VM Option for the Android Workstation

## Executive Summary

This repo now treats the Azure VM as the remote development machine and VS Code tunnel host, while the phone remains the browser client.

The opinionated default in this repo is:

- Ubuntu VM on Azure
- `outboundConnectivityMode = 'vmPublicIp'`
- no inbound SSH rule by default
- first-boot automation through VM `customData`
- browser-based VS Code on the phone as the primary workflow
- SSH kept only as an admin fallback

That means the deployment now automates the repeatable machine setup, but it still keeps the trust boundary around account authentication explicit.

## Current Design and Earlier Limitations

Before this session, the `azure-vm` stack already had the right broad architecture:

- subscription-scope Bicep entry point
- resource group creation through AVM
- Linux VM deployment through the AVM virtual machine module
- explicit outbound options (`vmPublicIp`, `natGateway`, `defaultOutbound`)
- no password auth
- optional inbound SSH from approved CIDRs only
- auto-shutdown and optional budget alerting

The weak point was first-use automation:

- the VM could deploy, but the actual machine setup still depended on a human logging in
- `azure-vm/scripts/bootstrap-vm.sh` existed, but it was a manual post-deploy step
- the VS Code tunnel still had to be installed and registered manually after first login
- SSH key generation and local parameter preparation were still mostly manual chores

This update shifts the repeatable work into provisioning and leaves only the account-auth step explicit.

## Honest Answers to the Key Questions

### How much can truly be automated?

For this repo and workflow, the following can be automated reliably:

- VM deployment
- network and NSG setup
- first-boot package update and base tooling install
- Azure CLI, Bicep CLI, Terraform, VS Code CLI, and optional Docker/GitHub CLI install
- linger enablement so a tunnel service can survive logout
- creation of a one-command tunnel registration helper on the VM
- local fallback SSH key generation and local parameter-file preparation from a phone-friendly shell

### What still requires a human, and why?

The unavoidable default human step is the first VS Code tunnel account sign-in.

Current Microsoft documentation for Remote Tunnels still describes hosting and connecting with the same GitHub or Microsoft account, and the normal flow is an interactive sign-in step. The local VS Code CLI currently exposes `code tunnel user login --provider`, plus token-based options, but token delivery is a separate secret-management problem.

So the honest default answer is:

- base VM bootstrap: yes, fully automated
- VS Code tunnel software install: yes, automated
- VS Code tunnel service persistence after registration: yes, automated
- initial tunnel identity registration: no, not by default

### Can the tunnel be authenticated automatically?

Technically, the current CLI supports token-based login:

- `code tunnel user login --access-token`
- `code tunnel user login --refresh-token`

However, this repo does not automate that by default because:

- `customData` is explicitly not a safe place for secrets
- injecting a long-lived tunnel token through deployment inputs is poor secret hygiene
- a clean, documented Microsoft flow for issuing and rotating those tokens as infrastructure input is not what the public Remote Tunnels docs center on

So the recommended design keeps tunnel authentication as a one-time human sign-in and automates everything before and after it.

### Do you need to manually connect after deployment?

Usually yes, once.

If you keep the secure default:

- `adminSshSourceCidrs = []`
- no tunnel auth token stored in Azure

then you will need one admin session after deployment to run the tunnel registration helper. After that, the tunnel service can start automatically on boot and the phone can stay browser-only.

### Is Key Vault justified here?

Not by default.

For this single-user dev/test setup, creating a Key Vault only to hold:

- an SSH private key
- or a VS Code tunnel token

adds complexity without improving the default trust model enough to justify it.

The better default is:

- generate the SSH key outside Azure
- keep the private key on your phone, laptop, or another key-management path you already trust
- deploy only the public key
- keep SSH closed by default and use it only as a temporary admin fallback

If you later want a fully unattended tunnel registration path and already have a mature secret-delivery pattern, then an existing Key Vault plus managed identity can be revisited. It is intentionally not the default in this repo.

## Opinionated Default Architecture

```text
Phone browser in Samsung DeX
        |
        v
VS Code tunnel endpoint
        |
        v
Azure Linux VM
  - Git
  - Azure CLI + Bicep
  - Terraform
  - language servers and extensions
```

Admin fallback:

```text
Termux / proot-distro / another admin shell
        |
        v
Temporary SSH from your current IP only
        |
        v
Azure Linux VM
```

Why this is the default:

- it preserves the browser-first phone workflow
- it avoids Azure Firewall
- it avoids NAT Gateway unless you explicitly want a no-public-IP design
- it keeps always-on cost low
- it keeps secrets out of deployment-time plaintext paths

## What Changed in the Repo

### Bicep changes

- `main.bicep` now exposes first-boot bootstrap controls and a stable `vscodeTunnelName`
- `modules/dev-vm-stack.bicep` now loads `scripts/bootstrap-vm.sh` and passes it into the VM as `customData`
- the example parameter file now includes the new bootstrap and tunnel-name parameters

### Bootstrap changes

`scripts/bootstrap-vm.sh` is now designed for both:

- unattended first boot through Azure VM provisioning
- manual reruns with `sudo` later if you need them

It now:

- installs the requested tooling automatically
- enables linger for the admin user
- writes `/usr/local/bin/android-workstation-tunnel-register`
- writes `/usr/local/bin/android-workstation-bootstrap-status`
- records status in `/var/lib/android-workstation/`
- logs to `/var/log/android-workstation-bootstrap.log`

### Phone-friendly helper

`scripts/prepare-local-deployment.sh` now:

- generates a local Ed25519 fallback SSH key if missing
- copies the example parameter file to a local ignored parameter file
- writes the generated public key into that local file
- sets `adminUsername`
- sets `vscodeTunnelName`
- prints the `what-if` and deployment commands to run next

## Files

- [main.bicep](./main.bicep)
- [modules/dev-vm-stack.bicep](./modules/dev-vm-stack.bicep)
- [parameters/westeurope.example.bicepparam](./parameters/westeurope.example.bicepparam)
- [scripts/bootstrap-vm.sh](./scripts/bootstrap-vm.sh)
- [scripts/prepare-local-deployment.sh](./scripts/prepare-local-deployment.sh)

## Deployment Flow

### 1. Prepare local inputs from the phone or another admin shell

Recommended environments:

- Termux plus `proot-distro` on the phone
- Azure Cloud Shell in the browser
- WSL or another Linux shell on a desktop

Run:

```bash
cd azure-vm/scripts
chmod +x prepare-local-deployment.sh
./prepare-local-deployment.sh
```

This creates or reuses:

- `~/.ssh/id_ed25519_android_workstation_vm`
- `azure-vm/parameters/westeurope.local.bicepparam`

The private key stays local. It is not uploaded to Azure by this template.

### 2. Review the deployment first

From the repo root:

```bash
az login --use-device-code

az deployment sub what-if \
  --location westeurope \
  --template-file azure-vm/main.bicep \
  --parameters @azure-vm/parameters/westeurope.local.bicepparam
```

### 3. Deploy

```bash
az deployment sub create \
  --location westeurope \
  --template-file azure-vm/main.bicep \
  --parameters @azure-vm/parameters/westeurope.local.bicepparam
```

### 4. Let first boot finish

On first boot, the VM now runs `customData` automatically.

What it does:

- OS updates
- developer packages
- official VS Code package and `code` CLI
- optional Azure CLI, Bicep, Terraform, GitHub CLI, Docker
- linger enablement
- helper script creation

Important Azure behavior to remember:

- Azure custom data on Linux is made available at provisioning time
- cloud-init processes scripts by default on supported Ubuntu images
- custom data is not a safe place for secrets
- custom data on single VMs is not updateable in-place later
- cloud-init script failures do not automatically mean ARM reports the VM as failed

To check the bootstrap state after you get an admin shell:

```bash
android-workstation-bootstrap-status
```

### 5. Perform the one-time manual tunnel registration

This is the one unavoidable default human step.

You need one admin shell on the VM so the machine can authenticate to your Microsoft or GitHub account.

Recommended path:

1. Temporarily set `adminSshSourceCidrs` in your local parameter file to your current public IP `/32`.
2. Run `what-if` again.
3. Redeploy.
4. SSH in from Termux or another shell.
5. Run the registration helper as the VM admin user.
6. Remove the CIDR again and redeploy to close SSH.

Example:

```bash
ssh -i ~/.ssh/id_ed25519_android_workstation_vm martin@<vm-public-ip>
android-workstation-tunnel-register microsoft
```

If you prefer GitHub auth:

```bash
android-workstation-tunnel-register github
```

What that helper does:

```bash
code tunnel user login --provider microsoft
code tunnel service install --accept-server-license-terms --name <configured-name>
code tunnel status
```

After that, the tunnel service should come back automatically on subsequent boots.

## Day-to-Day Operation From the Phone

The recommended daily pattern is:

1. Start the VM from the Azure mobile app or Azure portal.
2. Wait a short time for the VM and tunnel service to come up.
3. Open the tunnel URL in the phone browser.
4. Work normally in browser-based VS Code.
5. Let auto-shutdown stop the VM, or deallocate it manually when you finish.

This keeps the phone as a client only and keeps compute on the VM.

## Admin Access Recommendation

Best default:

- keep `adminSshSourceCidrs = []`
- keep the fallback SSH key outside Azure
- open SSH only temporarily from your current public IP when you need emergency admin access

Why not make SSH the primary workflow:

- it is not your desired interaction model
- the tunnel gives the better phone-browser experience
- keeping SSH closed by default reduces attack surface

## Secret Handling Recommendation

### SSH keys

Recommended:

- generate locally with `prepare-local-deployment.sh`
- deploy only the public key
- keep the private key local

Not recommended by default:

- generating the only private key inside Azure
- storing the SSH private key in a new Key Vault just for this VM

### VS Code tunnel tokens

Possible in principle:

- the CLI can accept an access token or refresh token

Not recommended by default here:

- storing that token in Bicep parameters
- passing it in VM `customData`
- creating a new Key Vault just to avoid one interactive login

## Cost and Security Notes

### Recommended cost posture

- use `Standard_B2ms` first
- use auto-shutdown
- manually start the VM only when needed
- deallocate it when done
- avoid Azure Firewall
- avoid NAT Gateway unless you have a hard no-public-IP requirement

### Current Microsoft pricing guidance used here

The current Microsoft pricing pages remain the source of truth, but many Azure price tables are rendered dynamically and do not expose all live numeric cells cleanly through static page retrieval.

So this README keeps the recommendation practical and cost-aware without freezing unverified rate-card numbers into the repo. Use the live pricing pages and calculator for your exact offer and region before deployment.

What is still clear from current Microsoft sources:

- Visual Studio Enterprise Azure credit is typically 150 USD per month for dev/test use
- dev/test subscriptions can have limitations, including continuously running instances being suspended after long runtimes
- Azure Virtual Network itself is free
- VM auto-shutdown is built in and intended to reduce off-hours cost
- explicit outbound is recommended as Azure moves new VNets toward private-by-default behavior after March 31, 2026

### Practical pricing tradeoff

For a single-user dev/test VM:

- `vmPublicIp` remains the best default
- NAT Gateway is cleaner architecturally, but it adds fixed hourly cost you do not need for this repo by default
- dedicated security services can dominate the bill faster than the VM itself if you leave them on

## Caveats

- `customData` is a first-boot mechanism. Changing the script later does not re-run it automatically on an existing single VM.
- If the bootstrap script fails, Azure may still show the VM provisioned because of cloud-init behavior. Check the bootstrap log if needed.
- If you keep SSH fully closed and do not provide a tunnel auth token through some other secure path, you still need one admin session after deployment.
- Remote Tunnels are single-user oriented. The same GitHub or Microsoft account must be used on both sides.

## Source Links

Microsoft Learn and Microsoft pricing pages used for this design:

- Remote Tunnels:
  https://code.visualstudio.com/docs/remote/tunnels
- VS Code command-line interface:
  https://code.visualstudio.com/docs/editor/command-line
- Azure VM custom data and cloud-init:
  https://learn.microsoft.com/en-us/azure/virtual-machines/custom-data
- Default outbound access:
  https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/default-outbound-access
- Auto-shutdown for Azure VMs:
  https://learn.microsoft.com/en-us/azure/virtual-machines/auto-shutdown-vm
- Azure virtual machines pricing:
  https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/
- Azure managed disks pricing:
  https://azure.microsoft.com/en-us/pricing/details/managed-disks/
- Azure virtual network pricing:
  https://azure.microsoft.com/en-us/pricing/details/virtual-network/
- Azure public IP pricing:
  https://azure.microsoft.com/en-us/pricing/details/ip-addresses/
- Azure Bastion pricing:
  https://azure.microsoft.com/en-us/pricing/details/azure-bastion/
- Azure dev/test pricing:
  https://azure.microsoft.com/en-us/pricing/offers/dev-test
- Visual Studio subscriber Azure credit guidance:
  https://learn.microsoft.com/en-us/answers/questions/2283042/can-i-use-my-msdn-visual-studio-enterprise-subscri
