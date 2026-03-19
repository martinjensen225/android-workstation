# Samsung Galaxy S25 Edge DeX Workstation Notes

This companion document holds the comparison, tradeoff, and review-style material that was split out of the setup guide. Read the main setup guide first if your goal is simply to build a working mobile workstation:

- [guide.md](./guide.md)

## 1. What This Setup Is Good For

Excellent:

- Markdown and note-taking
- Git operations
- Small to medium code edits
- Python, shell, Node.js, and infrastructure repo work
- SSH-based admin
- Reviewing pull requests
- Emergency fixes and low-risk development sessions

Tolerable:

- Small Bicep and Terraform edits
- Light web development
- Static site work
- Scripting and automation
- Cloud console work in a browser

Still a poor fit:

- Large local builds
- Docker-first workflows
- Android emulators, iOS tooling, or desktop hypervisors
- Heavy local databases
- Big monorepos with expensive indexing
- Multiple long-running local services
- Anything that absolutely depends on a full desktop IDE extension stack

The difference between "works in theory" and "comfortable enough for regular use" is mostly:

- Powered wired DeX instead of a weak dongle
- A real keyboard and mouse
- Keeping active repos in Termux storage
- Using browser AI beside the editor instead of forcing every desktop IDE flow into Android

## 2. Hardware Buying Advice

### Minimum viable setup

- Galaxy S25 Edge
- USB-C hub or USB-C to HDMI adapter with Power Delivery pass-through
- 25 W to 45 W USB-C PD charger
- One known-good USB-C cable for charging and one display cable that actually carries video
- 1080p portable monitor, desk monitor, or TV
- Bluetooth keyboard and mouse

### Better setup

- Galaxy S25 Edge
- USB-C hub with HDMI, USB-A, USB-C PD, and ideally Ethernet
- 45 W USB-C PD charger with a 100 W-rated cable
- 13 to 16 inch portable monitor with good brightness, matte screen, and either HDMI or USB-C video input
- Compact keyboard and a small mouse or trackball
- Foldable phone stand
- Optional USB-C SSD for archives, exports, and backups

### Practical hardware notes

- Bluetooth keyboard and mouse are the easiest match for a simple USB-C to HDMI cable.
- A real hub is better if you want wired peripherals, Ethernet, or SSD access.
- External SSDs are better for archives and exports than for your active Git working tree.
- Keep one HDMI fallback cable in your bag because portable USB-C display paths can be picky.

> [!WARNING]
> USB-C is still the easiest way to lose an hour. Many cables charge but do not carry video. Many cheap hubs advertise Power Delivery but still let the phone slowly drain during DeX.

## 3. Editor Option Comparison

| Option | Setup difficulty | Performance | Offline capability | Extension support | AI assistant compatibility | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| Local `code-server` in Termux | Medium | Good for small and medium repos | Yes | Medium, with marketplace friction | Partial and uneven | Best local fallback |
| Remote `code-server`, remote VS Code, or Codespaces | Medium to high | Usually best | No | Best overall | Best overall | Best if you have stable internet |
| Vim or Neovim in Termux | Medium if you already know it | Excellent | Yes | Good, but terminal-shaped | Good for Copilot, weaker for Codex | Best expert path |
| `github.dev` or `vscode.dev` | Low | Fine for quick edits | No | Limited to web extensions | Partial | Backup path only |
| Official VS Code via `proot-distro` and tunnel | High | Variable | Partly | Better than `code-server`, not guaranteed | Better chance with Microsoft marketplace | Best standard path |

### Why `proot-distro` and VS Code tunnel are now the default

- It has better alignment with supported VS Code behavior
- It gives a better chance of Microsoft-marketplace extension support
- It matches the workflow preference for this repo more closely than `code-server`
- It still pairs well with a second browser window for AI

### Why `code-server` is still worth keeping around

- It runs fully locally on the phone
- It works offline
- It is a useful fallback if the tunnel path is having a bad day

### Why Vim or Neovim can still be worth it

- It starts faster
- It uses less memory
- It fits `tmux`, Git, and SSH naturally
- It is less fragile than a browser tab

But if you are not already a Vim user, it is not the easiest path into this workstation.

## 4. Vim, Copilot, and Codex Notes

### Vim or Neovim plugin support in Termux

Plugin support is mostly normal because you still have a Unix-like shell environment. The categories that tend to work well are:

- Syntax and filetype plugins
- Git plugins
- LSP clients
- Fuzzy finders
- Treesitter-based highlighting, if native pieces compile cleanly
- AI completion plugins, with caveats

Friction usually shows up when plugins:

- Assume desktop clipboard tools
- Expect distro packages rather than Termux packages
- Shell out to binaries you did not install
- Assume a heavier desktop UI than a terminal-first Android workflow really wants

### GitHub Copilot in Vim or Neovim

GitHub has an official plugin:

- `github/copilot.vim`

This is the cleanest in-editor AI path for a terminal-first Termux setup.

### Codex in Vim or Neovim

Current OpenAI docs cover:

- Browser Codex
- Codex CLI
- Codex app
- Codex IDE extension for desktop editors

They do not document an official Vim or Neovim plugin.

That leaves two practical Termux options:

- Use Codex beside Vim in the browser or another terminal
- Try the community Termux fork `DioNanos/codex-termux`

`codex-termux` is useful, but it should still be treated as a community workaround rather than official OpenAI support.

## 5. `proot-distro` and Official VS Code

### The short version

Yes, `proot-distro` helps if your goal is official VS Code bits, the Microsoft marketplace, and a better chance of getting extensions to work than you get with `code-server`.

In this repo, that is why it is the standard editor path.

### Why this path is awkward

- `proot-distro` is PRoot, not a full VM
- PRoot is slower than native Linux
- Background behavior is still Android-shaped
- Microsoft does not position this as a normal supported local Linux desktop scenario
- Full GUI VS Code inside PRoot is a lot more awkward than a tunnel

### Best use of `proot-distro`

If you want to try this seriously, the best path is:

- Debian or Ubuntu inside `proot-distro`
- Install the official `code` package or CLI
- Run `code tunnel`
- Connect from the DeX browser

This gives you a better chance at official extension behavior than local `code-server`, without forcing a full nested GUI stack.

### Extension compatibility reality

Better than `code-server`, but not guaranteed.

Safer bets:

- Pure JavaScript or TypeScript extensions
- Extensions whose language servers ship Linux ARM64 binaries

Weaker bets:

- Extensions that assume `x86_64`
- Extensions with unusual native dependencies
- Alpine-based remote hosts

## 6. Codex, Copilot, and Browser AI

### Practical reality

- GitHub Copilot is strongest in supported desktop IDEs and on the GitHub website.
- `code-server` uses OpenVSX, not the Microsoft marketplace.
- Browser Codex is the clean official OpenAI path on Android.
- `codex-termux` is useful if you specifically want a terminal-first workflow on the phone.

### Recommended AI patterns

Best local pattern:

- Editor on the left
- Browser AI on the right

Best remote pattern:

- Remote repo or remote machine in the editor
- Codex or GitHub web features for larger repo-level tasks

What not to do by default:

- Build your whole workflow around getting every desktop AI extension to run locally on Android
- Let AI operate on the only copy of your branch without Git checkpoints

## 7. Azure and Linux Userspace Tradeoffs

### Azure Cloud Shell versus local Azure CLI

Cloud Shell wins when:

- You want the least friction
- You only need light admin work
- You do not want to maintain another Linux userspace

Local Azure CLI wins when:

- You want `az` beside a repo already on the phone
- You are willing to use Ubuntu in `proot-distro`
- You accept extra storage use and overhead

### UserLAnd versus `proot-distro`

UserLAnd is still useful if you want:

- A Play Store-installed distro
- A separate environment from Termux
- Terminal or VNC access managed by one Android app

`proot-distro` is still the better fit if:

- Termux is already your base environment
- You want one shell story
- You want one place for Git, repos, and tooling

UserLAnd is not a true VM. It is closer to a packaged Linux userspace on top of Android than to laptop-style virtualization.

## 8. Obsidian Git Plugin Reality

The Obsidian Git plugin can be tempting on mobile, but the safest setup is still:

- Obsidian for editing notes
- Termux for `git pull`, `git add`, `git commit`, and `git push`

The plugin is still the riskier path on Android, especially for larger vaults or plugin-heavy mobile vaults.

## 9. Honest Verdict

This setup is excellent as:

- A travel workstation
- A note-taking and lightweight coding station
- A Git and SSH machine
- A cloud admin companion

It is tolerable as:

- A small infrastructure editing station
- A quick-fix developer box
- A browser-first engineering workstation

It is not a real replacement for a laptop when you need:

- Heavy local development
- Rich desktop IDE integrations
- Containers and emulators
- Large builds
- Deep platform tooling

## References

- Samsung DeX support and FAQs:
  - https://www.samsung.com/us/support/answer/ANS10003477/
  - https://www.samsung.com/us/support/answer/ANS10001972/
- Termux install and source guidance:
  - https://github.com/termux/termux-app
  - https://github.com/termux-play-store
  - https://github.com/termux-user-repository/tur
  - https://github.com/termux/proot-distro
- VS Code:
  - https://code.visualstudio.com/download
  - https://code.visualstudio.com/docs/supporting/requirements
  - https://code.visualstudio.com/docs/remote/vscode-server
  - https://code.visualstudio.com/docs/remote/faq
  - https://code.visualstudio.com/docs/remote/linux
- code-server:
  - https://coder.com/docs/code-server/FAQ
- GitHub Copilot:
  - https://docs.github.com/en/copilot/get-started/features
  - https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent
  - https://github.com/github/copilot.vim
- OpenAI Codex:
  - https://developers.openai.com/codex/quickstart/
  - https://developers.openai.com/codex/models/
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
