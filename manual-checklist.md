# Manual Finishing Steps

## Before Running `bootstrap.sh`

- [ ] Install Termux from F-Droid or the official GitHub release, not the Play Store build.
- [ ] Connect the phone to reliable power if you are bootstrapping in Samsung DeX.
- [ ] If you are using DeX immediately, connect the powered hub, monitor, keyboard, and mouse, then launch wired DeX.

## During The First Bootstrap Run

- [ ] Approve the Android shared-storage prompt when `termux-setup-storage` opens it.
- [ ] Reopen Termux or run `source ~/.bashrc` after the script finishes.

## Git And SSH

- [ ] Run `github-ssh-key` and copy the public key into `GitHub > Settings > SSH and GPG keys`.
- [ ] Test GitHub SSH access with `ssh -T git@github.com`.
- [ ] If you use GitHub CLI, run `gh auth login --git-protocol ssh --web`.
- [ ] After SSH works, run `clone-managed-repos` if you enabled any repo entries in `manifest/repos.local.json`.

## Samsung DeX Tuning

- [ ] Set the physical keyboard layout in Samsung settings.
- [ ] Set pointer speed to something comfortable on the external display.
- [ ] Start with `1920x1080` if higher resolutions are unstable.
- [ ] Pin Termux, your browser, Obsidian, and the file manager to the DeX taskbar.
- [ ] Exempt Termux and your main browser from aggressive battery optimization if Samsung allows it.

## Editor Workflow

- [ ] Start `code-tunnel` and complete the Microsoft sign-in flow in the browser.
- [ ] Open the printed tunnel URL, trust the workspace, and install the formatter, YAML, TOML, Markdown, and language extensions you actually use there.
- [ ] If you want the local fallback editor too, enable `ENABLE_CODE_SERVER=true`, rerun `bootstrap.sh`, then start `code-web` and log in with the password from `.env`.
- [ ] If you enabled GitHub Copilot for Neovim, open `nvim` and run `:Copilot setup`.
- [ ] If you enabled `codex-termux`, run `codex` once and complete its sign-in or API-key setup flow.
- [ ] Open `chatgpt-codex` in the browser and sign in to ChatGPT for the side-by-side AI workflow from the guide.

## Obsidian

- [ ] Install the official Obsidian Android app.
- [ ] Open `Documents/Obsidian/work-vault` as a vault.
- [ ] Keep Git sync in Termux with `opull` and `osync` instead of relying on the mobile Obsidian Git plugin.

## Debian Workflow

- [ ] If you disabled the default Debian automation or want to reprovision it, run `setup-debian-workspace`.
- [ ] Add the Debian SSH public key shown during provisioning to GitHub if you plan to clone repos inside Debian.
- [ ] Run `az login --use-device-code` inside Debian if you enabled the local Azure CLI path.
- [ ] Install VS Code extensions from the Debian tunnel session only after the tunnel is working.

## Cloud And Browser Workflows

- [ ] Use `azure-shell` to open Azure Cloud Shell, then set the active subscription with `az account set --subscription "<SUBSCRIPTION_NAME_OR_ID>"`.
- [ ] Sign in to any browser-based tools that cannot be scripted, including ChatGPT, GitHub, Azure Portal, and any repo-hosted web tooling.

## Backup Habit

- [ ] Run `workstation-backup` after the first successful setup and again after meaningful config changes.
- [ ] Store the exported archive somewhere outside the phone if this setup needs to survive device loss or replacement.
