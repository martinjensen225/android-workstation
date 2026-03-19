# Android Workstation Bootstrap

This bundle turns the DeX workstation guide into a rerunnable, Termux-first bootstrap kit for a fresh Galaxy S25 Edge. It automates the repeatable shell and file-system work, and leaves app installs, Android permissions, GUI logins, and Samsung settings in a separate manual checklist.

## First Run on a New Phone

1. Install Termux from F-Droid or GitHub releases.
2. In Termux, fetch this public repo over HTTPS once so you can bootstrap before SSH is configured:

   ```sh
   pkg update && pkg install -y git
   mkdir -p ~/code/personal
   git clone https://github.com/martinjensen225/android-workstation.git ~/code/personal/android-workstation
   cd ~/code/personal/android-workstation
   cp .env.example .env
   nano .env
   bash bootstrap.sh
   ```

3. If you want manifest-driven repo clones, edit `manifest/repos.local.json` after the first run copies it from the example.
4. Reopen Termux or run `source ~/.bashrc`.
5. Finish the manual steps in [manual-checklist.md](./manual-checklist.md).

That initial `https://` clone is only the transport step for a brand-new phone. The bootstrap itself still sets up GitHub SSH keys and the intended SSH-based Git workflow for normal use after the first run.

If HTTPS cloning is not available for the repo, copy this repo to the phone by USB, cloud storage, or another existing sync path and run the same `cp .env.example .env`, `nano .env`, and `bash bootstrap.sh` flow from the repo root.

## What The Bootstrap Automates

- Validates Termux, updates packages, requests shared-storage access, and creates the `~/code`, `~/bin`, SSH, and config directory layout.
- Installs the Termux toolchain from the guide and provisions the standard Debian `proot-distro` workspace for VS Code tunnel when enabled.
- Applies shell aliases and helper commands for DeX use: `code-tunnel`, `code-tunnel-shell`, `code-web`, `opull`, `osync`, `chatgpt-codex`, `azure-shell`, `clone-managed-repos`, `setup-debian-workspace`, and `workstation-backup`.
- Configures Git, generates SSH keys if missing, installs a managed GitHub SSH config include, and seeds `known_hosts`.
- Creates the Debian VS Code tunnel workspace and Neovim starter config by default, and adds `code-server` config only when you enable the local fallback editor.
- Prepares the Obsidian shared-storage vault path and either initializes it or clones it once GitHub SSH is ready.
- Optionally installs `code-server`, GitHub Copilot for Neovim, `codex-termux`, and local Azure CLI inside Debian.
- Exports a reusable config backup that survives phone replacement without silently archiving private keys.

## What Stays Manual

- Installing Samsung DeX hardware, launching DeX, and tuning Samsung display, keyboard, pointer, and battery settings.
- Granting the Android storage permission when `termux-setup-storage` opens the OS prompt.
- Uploading the generated SSH public key to GitHub, signing in with `gh`, and approving any browser-based auth flows.
- Installing and signing into Obsidian Android, opening the vault, and choosing mobile plugins.
- Running `code tunnel`, signing into Microsoft in the browser, installing VS Code extensions in the tunnel session, running `:Copilot setup`, signing into ChatGPT/Codex in the browser, and any Codex or Copilot account-level setup.
- Running `az login --use-device-code`, `code tunnel`, and any Microsoft or Azure sign-in step inside Debian.
- Any UserLAnd workflow, because the guide keeps it explicitly outside the preferred automated path.

## Guide To Implementation Map

| Guide section | Implementation |
| --- | --- |
| 1. Collect the Hardware | [manual-checklist.md](./manual-checklist.md) |
| 2. Start Samsung DeX | [manual-checklist.md](./manual-checklist.md) |
| 3. Install and Prepare Termux | [bootstrap.sh](./bootstrap.sh), [manifest/bootstrap.json](./manifest/bootstrap.json), [templates/bashrc.sh.template](./templates/bashrc.sh.template) |
| 4. Configure Git and GitHub | [bootstrap.sh](./bootstrap.sh), [templates/ssh.github.conf.template](./templates/ssh.github.conf.template) |
| 5. Choose and Set Up an Editor | [bootstrap.sh](./bootstrap.sh), [scripts/setup-debian-workspace.sh](./scripts/setup-debian-workspace.sh), [scripts/debian-provision.sh](./scripts/debian-provision.sh), [templates/bin/code-tunnel.template](./templates/bin/code-tunnel.template), [templates/bin/code-tunnel-shell.template](./templates/bin/code-tunnel-shell.template), [templates/code-server.config.yaml.template](./templates/code-server.config.yaml.template), [templates/nvim.init.lua](./templates/nvim.init.lua), [templates/bin/code-web.template](./templates/bin/code-web.template) |
| 6. Set Up AI Assistance | [bootstrap.sh](./bootstrap.sh), [templates/bin/chatgpt-codex.template](./templates/bin/chatgpt-codex.template), [manual-checklist.md](./manual-checklist.md) |
| 7. Set Up Azure Access | [templates/bin/azure-shell.template](./templates/bin/azure-shell.template), [scripts/setup-debian-workspace.sh](./scripts/setup-debian-workspace.sh), [scripts/debian-provision.sh](./scripts/debian-provision.sh), [manual-checklist.md](./manual-checklist.md) |
| 8. Set Up Obsidian with Git | [scripts/setup-obsidian-vault.sh](./scripts/setup-obsidian-vault.sh), [templates/obsidian.gitignore.template](./templates/obsidian.gitignore.template), [templates/bin/opull.template](./templates/bin/opull.template), [templates/bin/osync.template](./templates/bin/osync.template) |
| 9. Daily Startup Routine | [templates/bashrc.sh.template](./templates/bashrc.sh.template), [templates/bin/code-tunnel.template](./templates/bin/code-tunnel.template), [templates/bin/code-web.template](./templates/bin/code-web.template), [templates/bin/chatgpt-codex.template](./templates/bin/chatgpt-codex.template) |
| 10. Troubleshooting | [manual-checklist.md](./manual-checklist.md), log output under `~/.local/state/android-workstation/logs/` |

## Rerun Behavior

- Safe to rerun: existing Termux packages, directories, SSH keys, repo clones, and managed shell hooks are detected and skipped when already in place.
- The bootstrap updates the required Git settings on each run, but it does not delete repos, keys, or user files.
- Existing `~/.config/nvim/init.lua` is preserved once you customize it, and existing `~/.config/code-server/config.yaml` is preserved if you enable the local fallback editor later. Generated defaults remain in `~/.config/android-workstation/`.
- Repo cloning waits until GitHub SSH authentication succeeds, so the main bootstrap can finish even before you upload the public key.

## Backup And Recovery

- Run `workstation-backup` to export a dated snapshot to `~/storage/shared/Documents/Backups/galaxy-dex-workstation`.
- The archive includes shell and editor config, the managed bootstrap files, public SSH material, and package metadata.
- Private SSH keys are intentionally excluded. Regenerate them on a replacement phone unless you choose to manage private-key backups outside this repo.
