# Samsung Galaxy S25 Edge as a Portable Samsung DeX Workstation Setup Guide

This document is the setup-first version of the guide. It is written as a practical walkthrough for building a working Samsung DeX workstation on a Galaxy S25 Edge.

If you want the comparison, tradeoff, and recommendation-heavy material that was split out of this file, read the companion notes document and the bootstrap bundle README:

- [notes.md](./notes.md)
- [README.md](./README.md)

> [!NOTE]
> Current reality, verified during March 2026:
> - The Galaxy S25 series supports wired and wireless Samsung DeX.
> - Samsung DeX on PC is not supported on Galaxy S25 series devices.
> - Termux is best installed from F-Droid or GitHub releases.
> - `proot-distro` with VS Code tunnel is the standard editor path for this setup.
> - `code-server` remains the local fallback editor path.
> - Azure CLI is better in Cloud Shell or a Linux userspace than in plain Termux.
> - The Obsidian Git plugin is still not the safest mobile Git path.

## 1. Collect the Hardware

Use this checklist before touching software:

- Galaxy S25 Edge
- USB-C hub or USB-C to HDMI adapter with Power Delivery pass-through
- 25 W to 45 W USB-C PD charger
- A USB-C cable that actually carries video
- HDMI cable or USB-C monitor cable
- External monitor, portable monitor, or TV
- Bluetooth or wired keyboard
- Bluetooth or wired mouse

Helpful extras:

- Foldable phone stand
- USB-C SSD for archives and backups
- Hub with Ethernet if you do a lot of remote admin work

> [!WARNING]
> Bad cables and weak hubs cause more problems than the phone does. If DeX is unstable, the first things to suspect are the cable, hub, and charger.

## 2. Start Samsung DeX

### Wired DeX: recommended path

1. Connect the USB-C hub or dock to power.
2. Connect the monitor to the hub with HDMI, or connect the phone directly to a USB-C monitor if it supports video input.
3. Connect the keyboard and mouse.
4. Plug the hub or display cable into the Galaxy S25 Edge.
5. Unlock the phone if needed.
6. Wait for DeX to start on the external display.

If DeX does not launch automatically:

1. Swipe down for Quick Settings.
2. Tap `DeX`.
3. If needed, open `Settings > Connected devices > Samsung DeX`.

### Optional: wireless DeX

Use this only if you accept more latency and battery drain.

1. Turn on the supported TV or monitor.
2. Swipe down for Quick Settings on the phone.
3. Tap `DeX`.
4. Choose `DeX on TV or monitor`.
5. Select the display and confirm the prompts.

### Configure DeX for regular use

After DeX starts, check these settings:

- `Settings > Connected devices > Samsung DeX > Connected display`
- `Settings > General management > Physical keyboard`
- Settings search for `Mouse and trackpad`
- Settings search for `Battery optimization`

Do this once:

1. Set your keyboard layout correctly.
2. Adjust pointer speed so the mouse feels normal on the external display.
3. Set the display to a stable starting resolution such as `1920x1080`.
4. Pin your browser, Termux, Obsidian, and file manager to the DeX taskbar.
5. Exempt Termux and your main browser from aggressive battery optimization if Samsung allows it.

## 3. Install and Prepare Termux

### Install Termux from the correct source

Use one of these:

- F-Droid
- Official GitHub releases

Do not treat the Google Play build as the default path for this setup.

### Run the initial setup

Open Termux and run:

```sh
pkg update && pkg upgrade -y
termux-setup-storage
pkg install -y git openssh curl wget nano vim neovim python nodejs-lts tmux ripgrep jq gh rsync zip unzip tar build-essential proot-distro
mkdir -p ~/code/work ~/code/personal ~/code/scratch ~/.ssh ~/bin
```

When `termux-setup-storage` prompts for storage permission, allow it.

Use this folder layout:

- `~/code/work` for work repos
- `~/code/personal` for personal repos
- `~/code/scratch` for experiments
- `~/storage/shared` only for files that normal Android apps must also access

### Optional shell quality-of-life setup

```sh
cat >> ~/.bashrc <<'EOF'
export EDITOR=nano
alias ll='ls -lah'
alias gs='git status -sb'
alias ga='git add -A'
alias gc='git commit'
alias gp='git pull --ff-only'
alias gpush='git push'
alias deb='proot-distro login debian'
# Run code-server on ~/code
alias code-web='code-server ~/code'

# Obsidian work vault path
OBSIDIAN_WORK_VAULT="$HOME/storage/shared/Documents/Obsidian/work-vault"

opull() {
  cd "$OBSIDIAN_WORK_VAULT" || return
  git pull
}

osync() {
  cd "$OBSIDIAN_WORK_VAULT" || return
  git add -A

  if git diff --cached --quiet; then
    echo "No changes to commit."
    return
  fi

  git commit -m "docs: vault sync $(date '+%Y-%m-%d %H:%M:%S')"
  git push
}


# Start Debian and run VS Code tunnel inside it
code-tunnel() {
  proot-distro login debian -- bash -lc 'cd ~/code && code tunnel'
}

# Start Debian, run VS Code tunnel, then keep the Debian shell open after tunnel exits
code-tunnel-shell() {
  proot-distro login debian -- bash -lc 'cd ~/code && code tunnel; exec bash'
}
EOF

source ~/.bashrc
```

## 4. Configure Git and GitHub

### Configure Git identity

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.ff only
git config --global core.editor "nano"
```

### Generate an SSH key

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519
```

### Add a minimal SSH config

```sh
cat > ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
ssh-keyscan github.com >> ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
```

### Load the key into the current Termux session

```sh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Add the key to GitHub

Print the public key:

```sh
cat ~/.ssh/id_ed25519.pub
```

Then in GitHub:

1. Open `Settings > SSH and GPG keys`.
2. Click `New SSH key`.
3. Name it something clear such as `S25 Edge Termux`.
4. Paste the key.
5. Save it.

### Test GitHub SSH access

```sh
ssh -T git@github.com
```

### Clone a repository

```sh
cd ~/code/work
git clone git@github.com:<your-user>/<your-repo>.git
cd <your-repo>
git status
```

### Optional: GitHub CLI

```sh
gh auth login --git-protocol ssh --web
```

## 5. Choose and Set Up an Editor

The standard path is official VS Code tunnel inside `proot-distro`. After that, this guide gives you four optional paths:

- Local `code-server` as a fallback editor
- Neovim in Termux
- `codex-termux` for a terminal Codex workflow
- UserLAnd if you want a Play Store-installed Linux userspace

### Standard path: official VS Code tunnel inside `proot-distro`

Use this as the primary editor workflow for this setup. It gives you the closest match to supported VS Code behavior and a better shot at Microsoft-marketplace extensions than local `code-server`.

This path creates a separate Debian userspace. That means Debian has its own:

- `git` installation
- SSH keys
- Git config
- cloned repos under `/root/code/...`

Do not assume your Termux Git setup carries over automatically.

Install Debian inside `proot-distro`:

```sh
pkg install -y proot-distro
proot-distro install debian
proot-distro login debian
```

Inside Debian, install the base tools you need:

```sh
apt update && apt upgrade -y
apt install -y ca-certificates curl wget gpg apt-transport-https git openssh-client
```

Configure Git inside Debian:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Create a fresh SSH key inside Debian:

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519
```

Create a minimal SSH config inside Debian:

```sh
cat > ~/.ssh/config <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
ssh-keyscan github.com >> ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
```

Print the Debian public key:

```sh
cat ~/.ssh/id_ed25519.pub
```

Then in GitHub:

1. Open `Settings > SSH and GPG keys`.
2. Click `New SSH key`.
3. Name it something clear such as `S25 Edge Debian proot-distro`.
4. Paste the key.
5. Save it.

Test GitHub SSH access from Debian:

```sh
ssh -T git@github.com
```

Create your repo folders and clone the repo inside Debian:

```sh
mkdir -p ~/code/martinjensen225 ~/code/MartinEJensenLab
cd ~/code/martinjensen225
git clone git@github.com:martinjensen225/avd-workstation.git
cd avd-workstation
git status
```

Add the Microsoft package repo and install VS Code inside Debian:

```sh
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/keyrings/packages.microsoft.gpg
chmod 644 /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt update
apt install -y code
```

Start a tunnel:

```sh
code tunnel
```

Then:

1. Follow the sign-in prompts that `code tunnel` prints.
2. Open the printed tunnel URL in the DeX browser.
3. In the tunnel browser window, choose `File > Open Folder`.
4. Open the folder that matches the cloned repo path:

```text
/root/code/<owner>/<repo>
```

5. Trust the workspace when VS Code asks.
6. Install the extensions you need from the VS Code interface.
7. Open the integrated terminal in VS Code and confirm you are inside the Debian repo checkout:

```sh
pwd
git status
```

8. Keep the tunnel process running while you use the browser session.

### Optional local fallback: `code-server`

Install the Termux User Repository and `code-server`:

```sh
pkg install -y tur-repo
pkg update
pkg install -y code-server
```

Create a local config:

```sh
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml <<'EOF'
bind-addr: 127.0.0.1:8080
auth: password
password: REPLACE_WITH_A_LONG_RANDOM_PASSWORD
cert: false
disable-telemetry: true
EOF
```

Start `code-server` inside `tmux`:

```sh
tmux new -A -s desk
code-server ~/code
```

Then open this in your browser:

```text
http://127.0.0.1:8080
```

Do this inside `code-server`:

1. Log in with the password from `config.yaml`.
2. Open your repo folder from `~/code`.
3. Open the Extensions view with `Ctrl+Shift+X`.
4. Install the formatter, YAML, TOML, Markdown, and language extensions you actually need from the available catalog.
5. Pin the browser tab or install it as a PWA/app-like shortcut if your browser supports it.

> [!TIP]
> Use CLI validation for Bicep and Azure tasks even if you install editor extensions. The CLI path is more dependable on this setup.

### Optional path: Neovim in Termux

If you already use Vim or Neovim, set up a lightweight terminal editor like this.

Install or confirm the packages:

```sh
pkg install -y neovim nodejs-lts git ripgrep
node -v
```

Create a minimal Neovim config:

```sh
mkdir -p ~/.config/nvim
cat > ~/.config/nvim/init.lua <<'EOF'
vim.o.number = true
vim.o.relativenumber = true
vim.o.termguicolors = true
vim.o.mouse = "a"
EOF
```

Start Neovim in a repo:

```sh
cd ~/code/work/<your-repo>
nvim .
```

### Optional path: GitHub Copilot in Neovim

GitHub's official plugin can be installed without a plugin manager by using Neovim's built-in package loading.

1. Confirm `node -v` reports Node.js 22 or newer.
2. Clone the plugin:

```sh
mkdir -p ~/.config/nvim/pack/github/start
git clone https://github.com/github/copilot.vim ~/.config/nvim/pack/github/start/copilot.vim
```

3. Open Neovim:

```sh
nvim
```

4. Run:

```vim
:Copilot setup
```

5. Complete the sign-in flow in the browser that opens.

### Optional path: Codex in Termux with `codex-termux`

This is a community Termux-specific Codex path, not the official OpenAI support path.

Install it:

```sh
npm install -g @mmmbuto/codex-cli-termux
```

Start it from a repo directory:

```sh
cd ~/code/work/<your-repo>
codex
```

Then:

1. Complete the sign-in or API-key setup prompts.
2. Keep it in a second `tmux` pane or terminal window while you edit in Neovim.
3. Use Git checkpoints before larger Codex tasks.

### Edit Codex settings and instructions inside the Debian tunnel

If you install the Codex VS Code extension in this Debian tunnel, edit its files from the Debian userspace, not from Termux.

The Codex IDE extension shares the same Codex config and instruction layers:

- User-level config: `~/.codex/config.toml`
- Global Codex instructions for every repo in this Debian userspace: `~/.codex/AGENTS.md`
- Repo-specific instructions: `AGENTS.md` in the repo root
- Narrower instructions for a subfolder: a deeper `AGENTS.md`

You can open the config file from the Codex extension gear menu with `Codex Settings > Open config.toml`, or just edit the files from the tunnel terminal:

```sh
mkdir -p ~/.codex
nano ~/.codex/config.toml
nano ~/.codex/AGENTS.md

cd /root/code/<owner>/<repo>
nano AGENTS.md
```

Use this split:

- Put your personal defaults in `~/.codex/AGENTS.md`
- Put repo conventions in the repo root `AGENTS.md`
- Put subfolder-specific rules in a deeper `AGENTS.md` only when that folder needs different behavior

After changing `~/.codex/config.toml`, restart Codex or start a new Codex task so the updated config is loaded. If `AGENTS.md` changes seem stale, restart Codex in that repo so it rebuilds the instruction chain.

> [!TIP]
> A repo cloned into `~/code` in Debian is part of the Debian userspace, not your Termux home. Treat the `proot-distro` VS Code path as its own workspace and clone the repo there on purpose.

### Optional path: UserLAnd

Use this only if you specifically want a Play Store-installed Linux userspace instead of building on Termux.

1. Install UserLAnd from Google Play.
2. Open the app and choose `Ubuntu` or `Debian`.
3. Choose a terminal or SSH session, not a VNC desktop, unless you explicitly want the extra overhead.
4. Set the username, password, and distro options when prompted.
5. Wait for the distro install to finish.
6. Open the session and run:

```sh
apt update && apt upgrade -y
apt install -y git curl wget openssh
```

Use UserLAnd mainly for:

- Terminal-only distro work
- Package-specific experiments
- Azure CLI if you prefer it over `proot-distro`

Do not make UserLAnd your first attempt at full desktop VS Code on the phone.

## 6. Set Up AI Assistance

### Default AI path: browser Codex beside the editor

1. Open your main editor in one DeX window.
2. Open `https://chatgpt.com/codex` in a second browser window.
3. Sign in.
4. If you want Codex to work on a GitHub repo remotely, connect the repository in the Codex environment settings.
5. Keep it side-by-side with the editor while you work.

Recommended layout:

- Left window: VS Code tunnel, `code-server`, or Neovim
- Right window: Codex or ChatGPT in the browser

### Optional AI path: GitHub web Copilot

1. Open the GitHub repository in the browser.
2. Sign in to your GitHub account with Copilot access.
3. Use Copilot Chat or repo-level Copilot features from the GitHub web UI when you want help with pushed code, PRs, or issues.

### Optional AI path: `codex-termux`

If you installed `codex-termux`, use it like this:

```sh
cd ~/code/work/<your-repo>
codex
```

Keep it in a second terminal pane or window so you can continue editing in Neovim or running Git commands in the main shell.

## 7. Set Up Azure Access

### Default path: Azure Cloud Shell

This is the cleanest Azure path on the phone.

1. Open Azure Portal or `https://shell.azure.com/bash`.
2. Sign in.
3. Start a Bash Cloud Shell session.
4. Clone your repo if you need it there:

```sh
git clone git@github.com:<your-user>/<your-repo>.git
cd <your-repo>
```

5. Verify the account and subscription:

```sh
az account list -o table
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"
az account show -o table
```

6. Run a small test command:

```sh
az group list -o table
```

7. For Bicep work:

```sh
az bicep version
az deployment group what-if \
  --resource-group "<RESOURCE_GROUP>" \
  --template-file infra/main.bicep \
  --parameters @infra/dev.bicepparam
```

### Optional local Azure CLI path: Debian in `proot-distro`

Use this if you want `az` beside repos that live on the phone.

Reuse the Debian userspace from the VS Code tunnel section. If you skipped that section, install and enter Debian:

```sh
pkg install -y proot-distro
proot-distro install debian
proot-distro login debian
```

Inside Debian:

```sh
apt update && apt upgrade -y
apt install -y curl ca-certificates apt-transport-https lsb-release gnupg git
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
```

The installer name is still `InstallAzureCLIDeb` because it targets Debian-based distributions.

Authenticate with device code:

```sh
az login --use-device-code
az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"
az account show -o table
az bicep version
```

### Optional Azure CLI path in UserLAnd

If you chose UserLAnd instead of `proot-distro`, use the same Debian-based Azure CLI install flow inside its Debian or Ubuntu session:

```sh
apt update && apt upgrade -y
apt install -y curl ca-certificates apt-transport-https lsb-release gnupg git
curl -sL https://aka.ms/InstallAzureCLIDeb | bash
az login --use-device-code
```

## 8. Set Up Obsidian with Git

### Create the vault in shared storage

The Obsidian vault should live in shared storage so both Obsidian and Termux can reach it.

Create the folder:

```sh
mkdir -p ~/storage/shared/Documents/Obsidian/work-vault/{inbox,daily,projects,reference,snippets,attachments}
```

### Create or clone the Git repository

If you are creating a brand new notes repo:

```sh
cd ~/storage/shared/Documents/Obsidian/work-vault
git init
git branch -M main
cat > .gitignore <<'EOF'
.obsidian/cache/
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash/
EOF
```

If you already have a vault repo:

```sh
cd ~/storage/shared/Documents/Obsidian
git clone git@github.com:<your-user>/<your-vault-repo>.git work-vault
```

### Open the vault in Obsidian

1. Install the official Obsidian Android app.
2. Open the app.
3. Choose `Open folder as vault`.
4. Pick `Documents/Obsidian/work-vault`.

### Use Termux for Git sync

Before writing:

```sh
cd ~/storage/shared/Documents/Obsidian/work-vault
git pull --rebase
```

After writing:

```sh
git add -A
git commit -m "notes: update work vault"
git push
```

## 9. Daily Startup Routine

Use this sequence for a normal work session:

1. Connect the phone to power, monitor, hub, keyboard, and mouse.
2. Let wired DeX start.
3. Open Termux.
4. Reattach or create your `tmux` session:

```sh
tmux new -A -s desk
```

5. Start your editor:

```sh
code-tunnel
```

6. In the VS Code tunnel terminal, sync your main repo:

```sh
cd /root/code/work/<your-repo>
git fetch --all --prune
git pull --ff-only
git status
```

Or:

```sh
cd ~/code/work/<your-repo>
nvim .
```

Or:

```sh
code-web
```

7. Open your AI helper beside the editor.
8. Do the work.
9. Commit and push:

```sh
git add -A
git commit -m "fix: describe the change"
git push -u origin HEAD
```

10. Pull and push your Obsidian vault from Termux.

## 10. Troubleshooting

### DeX does not start

- Unlock the phone before connecting it.
- Power the hub before plugging in the phone.
- Swap the cable first.
- Try a direct USB-C to HDMI path before blaming the phone.
- Do not spend time trying DeX on PC with the S25 Edge.

### Display or resolution is unstable

- Start at `1920x1080`.
- Check `Settings > Connected devices > Samsung DeX > Connected display`.
- Try a stronger charger.
- Replace the hub or HDMI cable.

### Termux cannot see shared storage

- Run `termux-setup-storage` again.
- Recheck Android storage permission prompts.
- Make sure the Obsidian vault is in `~/storage/shared/...`, not in Termux home.

### GitHub SSH authentication fails

- Re-run `ssh -T git@github.com`.
- Check the key in GitHub settings.
- Re-add the key to `ssh-agent`:

```sh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### `code-server` does not start

- Confirm `tur-repo` is installed.
- Run `pkg update`.
- Retry `pkg install code-server`.
- Start it inside `tmux`.

### Copilot in Neovim does not work

- Confirm `node -v` is new enough for the current plugin requirements.
- Reopen Neovim after cloning the plugin.
- Run `:Copilot setup` again.

### `code tunnel` inside `proot-distro` is unreliable

- Keep the tunnel process in the foreground or inside `tmux`.
- Prefer Debian or Ubuntu over Alpine.
- If this path becomes annoying, go back to local `code-server`.

### Azure CLI is painful locally

- Use Cloud Shell first.
- Use `az login --use-device-code` locally.
- Prefer Debian or Ubuntu inside `proot-distro` over trying to force Azure CLI into plain Termux.

### Obsidian Git sync is flaky

- Use Termux for Git operations instead of relying on the mobile Git plugin.
- Close Obsidian before a large pull if files appear stale.

### Heat, battery, or charging problems

- Use a stronger charger.
- Reduce display brightness.
- Stay on wired DeX.
- Let the phone breathe instead of trapping heat under papers or in a thick case.

## End Checklist

- [ ] Wired DeX works on the external display
- [ ] Keyboard and mouse both work
- [ ] The hub provides stable charging during DeX
- [ ] Termux is installed from F-Droid or GitHub
- [ ] Base Termux packages are installed
- [ ] Git name and email are configured
- [ ] SSH auth to GitHub works
- [ ] Repos clone into `~/code/...`
- [ ] The `proot-distro` VS Code tunnel works
- [ ] Optional Neovim path works
- [ ] Optional Copilot Neovim setup works
- [ ] Optional `codex-termux` setup works
- [ ] Optional `code-server` path works
- [ ] Optional UserLAnd distro session works
- [ ] Azure Cloud Shell works
- [ ] Optional local Azure CLI works
- [ ] Obsidian opens the shared-storage vault
- [ ] Notes sync from Termux works

## References

- Companion notes:
  - [notes.md](./notes.md)
- Samsung DeX:
  - https://www.samsung.com/us/support/answer/ANS10003477/
  - https://www.samsung.com/us/support/answer/ANS10001972/
- Termux:
  - https://github.com/termux/termux-app
  - https://github.com/termux-play-store
  - https://github.com/termux-user-repository/tur
  - https://github.com/termux/proot-distro
- VS Code:
  - https://code.visualstudio.com/download
  - https://code.visualstudio.com/docs/supporting/requirements
  - https://code.visualstudio.com/docs/remote/vscode-server
  - https://code.visualstudio.com/docs/remote/faq
- code-server:
  - https://coder.com/docs/code-server/FAQ
- GitHub Copilot:
  - https://docs.github.com/en/copilot/get-started/features
  - https://github.com/github/copilot.vim
- OpenAI Codex:
  - https://developers.openai.com/codex/quickstart/
  - https://developers.openai.com/codex/models/
  - https://developers.openai.com/codex/ide
  - https://developers.openai.com/codex/ide/settings
  - https://developers.openai.com/codex/config-basic
  - https://developers.openai.com/codex/guides/agents-md
  - https://github.com/DioNanos/codex-termux
- Azure CLI and Bicep:
  - https://learn.microsoft.com/en-us/cli/azure/azure-cli-support-lifecycle
  - https://learn.microsoft.com/cli/azure/get-started-with-azure-cli
  - https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install
  - https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-cli
- Obsidian Git:
  - https://github.com/Vinzent03/obsidian-git
- UserLAnd:
  - https://play.google.com/store/apps/details?id=tech.ula
  - https://github.com/CypherpunkArmory/UserLAnd/wiki
