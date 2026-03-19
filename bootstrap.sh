#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/common.sh"

update_termux() {
  log "Updating Termux package metadata"
  pkg update
  pkg upgrade -y
}

ensure_storage_access() {
  if [[ ! -d "$HOME/storage/shared" ]]; then
    log "Requesting shared-storage access from Android"
    termux-setup-storage
  fi

  if [[ ! -d "$HOME/storage/shared" ]]; then
    die "Shared storage is not available. Accept the Android storage prompt, then rerun bootstrap."
  fi
}

create_directories_from_manifest() {
  local raw_path

  while IFS= read -r raw_path; do
    ensure_directory "$(expand_home_tokens "$raw_path")"
  done < <(jq -r '.directories.termux[], .directories.sharedStorage[]' "$BOOTSTRAP_MANIFEST_PATH")
}

install_termux_packages_from_manifest() {
  local package_name

  ensure_termux_package jq

  while IFS= read -r package_name; do
    ensure_termux_package "$package_name"
  done < <(jq -r '.termux.corePackages[]' "$BOOTSTRAP_MANIFEST_PATH")

  if bool_is_true "$ENABLE_NEOVIM"; then
    while IFS= read -r package_name; do
      ensure_termux_package "$package_name"
    done < <(jq -r '.termux.editorPackages[]' "$BOOTSTRAP_MANIFEST_PATH")
  fi

  if bool_is_true "$ENABLE_CODE_SERVER"; then
    ensure_termux_package tur-repo
    pkg update
    while IFS= read -r package_name; do
      ensure_termux_package "$package_name"
    done < <(jq -r '.termux.turPackages[]' "$BOOTSTRAP_MANIFEST_PATH")
  fi
}

install_optional_node_packages() {
  if ! bool_is_true "$ENABLE_CODEX_TERMUX"; then
    return
  fi

  if npm list -g --depth=0 @mmmbuto/codex-cli-termux >/dev/null 2>&1; then
    log "codex-termux is already installed"
    return
  fi

  log "Installing optional codex-termux package"
  npm install -g @mmmbuto/codex-cli-termux
}

configure_git() {
  log "Configuring Git identity"
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
  git config --global init.defaultBranch main
  git config --global pull.ff only
  git config --global core.editor "$TERMUX_EDITOR"
}

configure_ssh() {
  log "Configuring SSH for GitHub"
  ensure_directory "$HOME/.ssh"
  ensure_directory "$HOME/.ssh/config.d"
  chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"

  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    log "Generating SSH key at $SSH_KEY_PATH"
    ssh-keygen -q -t ed25519 -C "$SSH_KEY_COMMENT" -f "$SSH_KEY_PATH" -N "$SSH_KEY_PASSPHRASE"
  else
    log "SSH key already present at $SSH_KEY_PATH"
  fi

  touch "$HOME/.ssh/config"
  ensure_line_once "$HOME/.ssh/config" "Include ~/.ssh/config.d/*.conf"
  chmod 600 "$HOME/.ssh/config"

  render_template "$BUNDLE_ROOT/templates/ssh.github.conf.template" "$HOME/.ssh/config.d/github-bootstrap.conf" 600
  ensure_known_host
}

install_shell_environment() {
  log "Installing shell helpers and wrapper commands"
  ensure_directory "$BOOTSTRAP_CONFIG_ROOT"
  ensure_directory "$TERMUX_BIN_ROOT"

  render_template "$BUNDLE_ROOT/templates/bashrc.sh.template" "$BOOTSTRAP_CONFIG_ROOT/bashrc.sh" 644
  ensure_line_once "$HOME/.bashrc" 'source "$HOME/.config/android-workstation/bashrc.sh"'

  local template_path output_name
  for template_path in "$BUNDLE_ROOT"/templates/bin/*.template; do
    output_name="$(basename "$template_path" .template)"
    render_template "$template_path" "$TERMUX_BIN_ROOT/$output_name" 755
  done
}

install_code_server_config() {
  if ! bool_is_true "$ENABLE_CODE_SERVER"; then
    return
  fi

  log "Installing code-server configuration"
  render_template "$BUNDLE_ROOT/templates/code-server.config.yaml.template" "$BOOTSTRAP_CONFIG_ROOT/code-server-config.yaml" 600

  if [[ ! -f "$HOME/.config/code-server/config.yaml" ]]; then
    render_template "$BUNDLE_ROOT/templates/code-server.config.yaml.template" "$HOME/.config/code-server/config.yaml" 600
  else
    log "Existing code-server config detected, leaving it untouched"
  fi
}

install_nvim_config() {
  if ! bool_is_true "$ENABLE_NEOVIM"; then
    return
  fi

  log "Installing Neovim starter configuration"
  cp -a "$BUNDLE_ROOT/templates/nvim.init.lua" "$BOOTSTRAP_CONFIG_ROOT/nvim-init.lua"
  chmod 644 "$BOOTSTRAP_CONFIG_ROOT/nvim-init.lua"

  if [[ ! -f "$HOME/.config/nvim/init.lua" ]]; then
    cp -a "$BUNDLE_ROOT/templates/nvim.init.lua" "$HOME/.config/nvim/init.lua"
    chmod 644 "$HOME/.config/nvim/init.lua"
  else
    log "Existing Neovim init.lua detected, leaving it untouched"
  fi

  if bool_is_true "$ENABLE_GITHUB_COPILOT_VIM"; then
    install_copilot_vim
  fi
}

install_copilot_vim() {
  if ! bool_is_true "$ENABLE_NEOVIM"; then
    die "ENABLE_GITHUB_COPILOT_VIM requires ENABLE_NEOVIM=true"
  fi

  local node_major copilot_path
  node_major="$(node -p "process.versions.node.split('.')[0]")"
  if (( node_major < 22 )); then
    die "GitHub Copilot for Neovim requires Node.js 22 or newer. Current major version: $node_major"
  fi

  copilot_path="$HOME/.config/nvim/pack/github/start/copilot.vim"
  if [[ -d "$copilot_path/.git" ]]; then
    log "GitHub Copilot for Neovim is already installed"
    return
  fi

  ensure_directory "$(dirname "$copilot_path")"
  log "Installing GitHub Copilot for Neovim"
  git clone --depth 1 https://github.com/github/copilot.vim "$copilot_path"
}

print_summary() {
  log "Bootstrap complete"
  printf '\n'
  printf '%s\n' "Next steps:"
  printf '%s\n' "  - Reopen Termux or run: source ~/.bashrc"
  printf '%s\n' "  - Print your GitHub public key with: github-ssh-key"
  printf '%s\n' "  - Finish the manual checklist: $BUNDLE_ROOT/manual-checklist.md"
  if bool_is_true "$ENABLE_DEBIAN_WORKFLOW"; then
    if bool_is_true "$ENABLE_VSCODE_TUNNEL"; then
      printf '%s\n' "  - Start the standard editor workflow with: code-tunnel"
    else
      printf '%s\n' "  - Enter the Debian workspace with: deb"
    fi
  elif bool_is_true "$ENABLE_CODE_SERVER"; then
    printf '%s\n' "  - Start the local fallback editor with: code-web"
  fi
  printf '%s\n' "  - Latest bootstrap log: $LOG_FILE"
}

main() {
  assert_termux
  load_environment "${1:-}"
  validate_required_configuration
  setup_logging

  log "Starting Samsung Galaxy S25 Edge DeX workstation bootstrap"
  update_termux
  ensure_storage_access
  create_directories_from_manifest
  install_termux_packages_from_manifest
  install_optional_node_packages
  configure_git
  configure_ssh
  install_shell_environment
  install_code_server_config
  install_nvim_config
  "$BUNDLE_ROOT/scripts/setup-obsidian-vault.sh"
  "$BUNDLE_ROOT/scripts/clone-repos.sh"

  if bool_is_true "$ENABLE_DEBIAN_WORKFLOW"; then
    "$BUNDLE_ROOT/scripts/setup-debian-workspace.sh"
  fi

  print_summary
}

main "$@"
