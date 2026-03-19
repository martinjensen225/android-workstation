# Azure VM Option for the Android Workstation

## 1. Executive Summary

Hosting the development environment and the VS Code tunnel on an Azure Linux VM is a good idea for your setup if you treat it as an on-demand complement to the phone-hosted Debian path, not as a total replacement for it.

The big wins are:

- Much better extension compatibility than Debian-in-`proot-distro` on the phone, because the VM is a normal Azure Linux host instead of an Android-shaped userspace.
- Much lower battery drain and heat on the phone because the phone becomes a browser client only.
- A more comfortable Samsung DeX experience for longer sessions because indexing, language servers, Git operations, and package installs move off-device.

The tradeoff is that you take on Azure cost and a little cloud-ops overhead. For your stated single-user dev/test use case, that trade is worth it if:

- you already have the monthly Visual Studio Enterprise Azure credit
- you only run the VM when needed
- you keep the design private by default and avoid paid security add-ons that dominate the budget

The best overall pattern is hybrid:

- Keep the existing phone-hosted Debian/`proot-distro` tunnel path as your offline and emergency fallback.
- Use the Azure VM as the better online primary for longer or more extension-sensitive sessions.

## 2. Corrected Architecture Statement

This is the target architecture evaluated and implemented here:

- The phone remains the client.
- The Azure VM becomes the remote development machine.
- The VS Code tunnel runs on the Azure VM.
- You connect to that tunnel from the browser on your phone in Samsung DeX.
- Remote SSH is not the primary workflow. It is only an admin fallback if you explicitly enable it or use Azure portal admin paths.

## 3. Assumptions and Constraints

- Single-user personal dev/test workload.
- Visual Studio Enterprise monthly Azure credit assumed: 150 USD per month.
- Region assumption for cost modeling: `West Europe`.
- OS assumption: Ubuntu Linux on Azure.
- Primary access pattern: browser-based VS Code over a VS Code tunnel.
- Security requirement: no Azure Firewall, avoid unnecessary always-on paid services.
- IaC requirement: Bicep, with Azure Verified Modules where safely applied.
- Current repo context: the phone-hosted `proot-distro` path remains valid and is not being replaced at the client layer.

Source notes:

- Microsoft Q&A confirms Visual Studio Enterprise includes 150 USD monthly credit and that the monthly cap resets rather than rolling over.
- Microsoft Q&A also notes Visual Studio credit subscriptions are best-effort for dev/test and can suspend continuously running instances that exceed 120 hours.
- Azure Bastion FAQ states Bastion pricing is hourly from deployment until deletion.
- Azure Bastion pricing page currently shows Azure Bastion Developer as free.
- Azure VM pricing pages confirm VM compute stops billing when the state is `Stopped (Deallocated)`, while managed disks still bill.
- Azure Managed Disk pricing pages confirm disks bill independently from VM runtime.

Pricing note:

- Azure's public pricing pages do not expose every live numeric cell in static HTML, so the tables below are practical estimates rather than invoice guarantees.
- The numbers are intentionally conservative and good enough for design decisions.
- Before you deploy, you should still confirm the exact figure for your final SKU in the Azure pricing calculator for your subscription offer.

## 4. Options Comparison Table

| Option | Cost | Setup complexity | Security posture | Extension compatibility | Browser responsiveness from phone | Battery and heat on phone | Operational friction | Reliability | DeX fit | Honest verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Phone-hosted Debian in `proot-distro` plus VS Code tunnel | Lowest direct cloud cost | Medium to high | Good if you keep everything local and outbound-only | Better than local `code-server`, still ARM64 and Android-shaped | Fine for light work, weaker for heavier indexing | Worst of the three | Lowest cloud friction, highest device babysitting | Depends on Android background behavior, battery, thermals | Strong when offline matters | Best zero-cost fallback, but still compromised by phone limits |
| Azure Linux VM plus VS Code tunnel | Low if you stop the VM, moderate if you forget | Medium | Best balance when private-by-default and no public IP | Best overall for your stated workflow | Usually best if the network is stable | Best | Some Azure management overhead, but manageable | Better than phone-hosted for long sessions | Excellent because DeX client stays the same | Best overall online option |
| Azure Linux VM plus Remote SSH only | Similar VM cost | Medium to high | Good if hardened correctly | Strong on desktop, weak for phone-browser workflow | Poor fit for phone browser because Remote SSH expects a richer client | Best | Higher friction from the phone | Good technically, but wrong interaction model | Weak for your stated browser-first DeX flow | Not recommended as the primary path |

## 5. Cost Breakdown and Scenario Analysis

### Cost model assumptions

- Region: `West Europe`
- VM OS: Ubuntu Linux
- OS disk: `64 GiB StandardSSD_LRS`
- Recommended security model: no public IP, no paid Bastion, no Azure Firewall
- Estimated fixed monthly carry cost while deallocated: about `5.50 USD` for the OS disk
- Estimated outbound network cost for this text-heavy workflow: negligible unless you start pulling large container images or big package caches regularly

### What still costs money while the VM is deallocated

- Managed OS disk
- Public IP if you choose to allocate one
- Paid Bastion SKUs if you deploy them
- Any serverless helper you deliberately leave in place, although those are usually pennies at this scale

### What stops costing money when the VM is deallocated

- VM compute
- VM license meter for the Ubuntu guest

### VM size recommendations and scenario totals

These scenario totals include the fixed OS disk carry cost.

| SKU | Experience | 1h weekdays plus small weekend use | 2h weekdays plus small weekend use | 4h weekdays plus weekend use | Worst realistic month | Accidental overuse month | Fits 150 USD credit? |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `Standard_B2s` | Good enough for tunnel, Git, CLI, light repo work. Too tight for heavier language servers or containers. | 6.80 USD | 7.90 USD | 10.30 USD | 12.90 USD | 41.50 USD | Yes, comfortably |
| `Standard_B2ms` | Best value pick. Comfortable for tunnel, Git, Azure CLI, Bicep, Terraform, and light containers. | 8.10 USD | 10.30 USD | 15.10 USD | 20.30 USD | 77.50 USD | Yes, comfortably |
| `Standard_D2as_v5` | More consistently snappy than burstable B-series. Good if you dislike burst-credit behavior. | 8.36 USD | 10.78 USD | 16.06 USD | 21.78 USD | 84.70 USD | Yes, comfortably |
| `Standard_D4as_v5` | Comfortable and roomy, but starts to feel wasteful for this use case. | 11.22 USD | 16.06 USD | 26.62 USD | 38.06 USD | 163.90 USD | Yes for normal use, risky if you forget to stop it |

### Recommended VM sizes

1. `Standard_B2ms`
   Best overall value for your use case. Enough RAM for a real browser tunnel session, Git, Azure CLI, Bicep, Terraform, and some light container use without paying for a larger general-purpose box.

2. `Standard_D2as_v5`
   Best pick if you want more predictable CPU behavior than B-series. Slightly more expensive, but still easily inside the credit.

3. `Standard_B2s`
   Fine if you want the cheapest option and your work stays light. I would not make this the only VM if you expect heavier extensions or occasional containers.

4. `Standard_D4as_v5`
   Comfortable but not cost-optimal. Good only if you know you need more RAM or more CPU headroom.

### Credit buffer by scenario for the recommended `Standard_B2ms`

| Scenario | Estimated total | Remaining buffer inside 150 USD credit | Cost risk |
| --- | --- | --- | --- |
| 1h weekdays plus small weekend use | 8.10 USD | 141.90 USD | Very low |
| 2h weekdays plus small weekend use | 10.30 USD | 139.70 USD | Very low |
| 4h weekdays plus weekend use | 15.10 USD | 134.90 USD | Low |
| Worst realistic month | 20.30 USD | 129.70 USD | Low |
| Accidental overuse month | 77.50 USD | 72.50 USD | Moderate, but still survivable inside the credit |

### Non-obvious cost components

- Public IP:
  small recurring charge if you enable one, plus bigger attack surface
- Bastion Developer:
  free, but portal-only and limited, so it is an admin fallback rather than a workflow platform
- Bastion Basic or Standard:
  not cost-justified here because it is always-on and likely becomes one of the largest line items in the stack
- Automation, Logic App, or Function start triggers:
  low direct spend at this scale, but not zero in operational overhead
- Monitoring:
  avoid turning on more than you need, because log ingestion can exceed the VM cost surprisingly quickly

## 6. Security Comparison

### Option A: No public IP, VS Code tunnel only

- Attack surface:
  lowest. The VM only needs outbound internet access for the tunnel and package updates.
- Recurring cost:
  lowest
- Operational friction:
  moderate on day one because you need an admin fallback for bootstrap and repair
- Suitability:
  excellent for a single-user dev/test VM
- Recommendation:
  yes, this is the default recommendation

### Option B: No public IP, plus Azure Bastion Developer for emergency admin

- Attack surface:
  still low, because the VM remains private
- Recurring cost:
  effectively zero based on the current Bastion pricing page
- Operational friction:
  low enough for occasional admin, but not pleasant enough to be your daily development path
- Suitability:
  excellent as a repair and first-login path
- Recommendation:
  yes, as the admin fallback

### Option C: No public IP, paid Azure Bastion Basic or Standard

- Attack surface:
  still very good
- Recurring cost:
  poor fit, because Bastion is billed hourly from deployment until deletion
- Operational friction:
  low
- Suitability:
  technically strong, financially weak for a single-user dev/test VM
- Recommendation:
  no

### Option D: Public SSH with strong hardening and NSG restrictions

- Attack surface:
  materially larger than tunnel-only
- Recurring cost:
  still low, but higher than private-only because of the public IP
- Operational friction:
  low once configured
- Suitability:
  acceptable only if you explicitly want direct SSH
- Recommendation:
  only as an opt-in fallback, not the default

### NSG-only and JIT notes

- NSG-only is good hygiene, but it does not replace the security benefit of avoiding a public IP altogether.
- Just-In-Time access can be useful when you expose SSH publicly, but it adds complexity and is not necessary for the recommended tunnel-only design.

## 7. Start/Stop Trigger Comparison

| Option | Security | Cost | Complexity | Reliability | Ease from phone | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| Azure mobile app or Azure portal manual start, built-in VM auto-shutdown | Strong, because there is no public webhook | Zero extra service cost | Lowest | High | Very good | Default |
| Azure Automation runbook with webhook | Depends on webhook hygiene | Usually low | Medium | Good | Good with a phone shortcut | Optional only if you really want one-tap start |
| Logic App HTTP trigger | Depends on URL secrecy and optional extra auth | Low | Medium | Good | Very good | Viable, but not needed by default |
| Function App endpoint | Can be made strong, but more moving parts | Low at this scale | Highest of the listed options | Good if maintained | Good | Overkill here |
| Always-on scheduler or start/stop solution | Fine | Low direct cost | Higher than needed | Good | Not a true on-demand model | Not recommended as the primary mechanism |

Default approach:

- Start the VM manually from the Azure mobile app or Azure portal from the phone.
- Use built-in auto-shutdown on the VM every evening.
- Add a subscription budget alert for cost guardrails.

That gives you the best security-to-friction ratio because there is no extra webhook or public endpoint to protect.

## 8. Final Recommendation

The best overall design for your use case is:

- `Standard_B2ms` Ubuntu VM in `West Europe`
- no public IP by default
- VS Code tunnel hosted on the VM
- browser on the phone remains the client
- Azure Bastion Developer only as the emergency admin path
- built-in VM auto-shutdown
- manual start from Azure mobile app or Azure portal
- optional subscription budget alert at 100 USD

This is the best balance of:

- security
- low cost
- minimal friction
- strong extension compatibility
- a clean fit for the browser-based DeX workflow
- staying comfortably inside the monthly Azure credit

## 9. Target Architecture

```text
Samsung DeX browser on phone
        |
        v
VS Code tunnel service
        |
        v
Azure Linux VM
  - Git
  - Azure CLI
  - Bicep
  - Terraform
  - language servers and extensions
```

Admin path:

```text
Azure portal on phone
        |
        v
Azure Bastion Developer or optional restricted SSH
        |
        v
Azure Linux VM
```

## 10. Azure Resource List

Lean recommended resource set:

- Resource group
- Virtual network
- One subnet
- Network security group
- Linux VM with system-assigned managed identity
- Managed OS disk
- Optional subscription budget

Intentionally omitted by default:

- Public IP
- Azure Firewall
- Paid Bastion
- Key Vault
- Logic App
- Function App
- Automation Account
- Log Analytics workspace

## 11. Bicep Solution

Files:

- [main.bicep](./main.bicep)
- [modules/dev-vm-stack.bicep](./modules/dev-vm-stack.bicep)
- [parameters/westeurope.example.bicepparam](./parameters/westeurope.example.bicepparam)

AVM usage in this solution:

- Resource group uses `br/public:avm/res/resources/resource-group:0.4.0`
- Virtual machine uses `br/public:avm/res/compute/virtual-machine:0.21.0`

Native Bicep is used for:

- virtual network
- subnet
- network security group
- subscription budget

Why native Bicep is used there:

- the stack is intentionally lean
- the VM AVM already creates the NIC and optional public IP cleanly
- the resource group and VM AVM modules were locally verifiable from the Bicep module cache on this workstation
- keeping the network pieces native here avoids guessing additional AVM module interfaces in an offline shell

## 12. VM Bootstrap and Tunnel Setup Guide

Files:

- [scripts/bootstrap-vm.sh](./scripts/bootstrap-vm.sh)

### First admin login

Recommended path:

1. Deploy the Bicep with `enablePublicIp=false`.
2. Open the Azure portal on the phone.
3. Use Azure Bastion Developer from the VM blade for the first SSH session.
4. Clone this repo or paste the script into the VM.

### Run the bootstrap script

```bash
git clone https://github.com/martinjensen225/android-workstation.git
cd android-workstation/azure-vm/scripts
chmod +x bootstrap-vm.sh
sudo TARGET_USER="$USER" ./bootstrap-vm.sh
```

Optional flags:

```bash
sudo TARGET_USER="$USER" INSTALL_DOCKER=true INSTALL_GITHUB_CLI=true ./bootstrap-vm.sh
```

### What the script installs

- package updates
- Git
- curl, wget, jq, ripgrep, tmux, build tools
- Azure CLI
- Terraform
- official VS Code package and `code` CLI
- optional Docker

### Configure the VS Code tunnel

Run this once as your normal user:

```bash
code tunnel
```

Then:

1. Complete the Microsoft sign-in flow.
2. Note the tunnel URL shown by the command.
3. Open that URL in the browser on your phone.
4. Trust the workspace and install the extensions you want on the VM-hosted tunnel.

To keep the tunnel available after logout:

```bash
sudo loginctl enable-linger "$USER"
code tunnel service install
```

If the CLI prompts differ slightly in a future VS Code release, the fallback is still the same:

- run `code tunnel`
- complete sign-in
- then install the service from the authenticated user context

## 13. Deployment and Operating Guide

### Deploy the Bicep

```bash
az deployment sub create \
  --location westeurope \
  --template-file azure-vm/main.bicep \
  --parameters @azure-vm/parameters/westeurope.example.bicepparam
```

### Start the VM from your phone

Default recommendation:

- use the Azure mobile app or Azure portal
- pin the VM blade in the portal or save it as a browser shortcut
- start the VM manually only when you intend to use it

### Stop the VM safely

- let auto-shutdown catch the common case
- manually stop and deallocate it from the portal when you finish early
- confirm the state is `Stopped (Deallocated)`, not just `Stopped`

### Avoid unnecessary cost

- keep the public IP disabled unless you really need it
- do not deploy paid Bastion SKUs
- do not add Azure Firewall
- keep log ingestion minimal
- use the budget alert
- leave the VM size at `Standard_B2ms` unless you prove you need more

### Maintain the VM over time

- apply package updates regularly
- keep the VS Code CLI current with package updates
- review disk usage before it silently forces a disk resize
- prune stale container images if you install Docker
- keep the SSH key list tight if you ever enable direct SSH

### What to monitor

- monthly credit burn
- VM state
- tunnel reliability
- disk growth
- package update backlog

## 14. Risks, Caveats, and Future Improvements

- This design is online-dependent. The phone-hosted Debian path is still your offline fallback.
- Azure browser latency will be better for heavy editor work, but worse than local for complete internet outages.
- If you choose burstable B-series, sustained CPU-heavy workloads can feel less predictable than D-series.
- If you start using more containers, `Standard_D2as_v5` may become the better pick.
- If you later want true one-tap start from the phone, the next sensible addition is a small webhook-triggered Automation or Logic App path.
- If you later need stronger admin access than Bastion Developer provides, add a temporary public IP or move to a paid Bastion SKU only after checking the exact price impact.

## Microsoft Documentation and Pricing Links

- Visual Studio subscriber credit guidance:
  - https://learn.microsoft.com/en-us/answers/questions/307496/if-subscription-visual-studio-enterprise-subscript
  - https://learn.microsoft.com/en-us/answers/questions/412125/does-visual-studio-enterprise-associated-azure-cre
- Azure VM pricing and billing behavior:
  - https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/
- Azure Managed Disks pricing:
  - https://azure.microsoft.com/en-us/pricing/details/managed-disks/
- Azure Bastion FAQ:
  - https://learn.microsoft.com/en-us/azure/bastion/bastion-faq
- Azure Bastion pricing:
  - https://azure.microsoft.com/en-us/pricing/details/azure-bastion/
- Auto-shutdown for Azure VMs:
  - https://learn.microsoft.com/en-us/azure/virtual-machines/auto-shutdown-vm
- Azure Bastion deployment guidance:
  - https://learn.microsoft.com/en-us/azure/bastion/quickstart-deploy-terraform
