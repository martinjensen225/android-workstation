#!/usr/bin/env bash

set -Eeuo pipefail

log() {
  printf '[debian %s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

warn() {
  printf '[debian %s] WARN: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

is_true() {
  case "${1:-false}" in
    true|TRUE|1|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ensure_package_list() {
  local package_list="$1"
  if [[ -z "$package_list" ]]; then
    return
  fi

  # shellcheck disable=SC2086
  apt install -y $package_list
}

ensure_workspace_directories() {
  local path_list="$1"
  local old_ifs="$IFS"
  IFS='|'
  for directory_path in $path_list; do
    mkdir -p "$directory_path"
  done
  IFS="$old_ifs"
}

ensure_known_host() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  touch "$HOME/.ssh/known_hosts"
  chmod 600 "$HOME/.ssh/known_hosts"

  if ! ssh-keygen -F "$PRIMARY_GITHUB_HOST" -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1; then
    ssh-keyscan -H "$PRIMARY_GITHUB_HOST" >> "$HOME/.ssh/known_hosts"
  fi
}

github_ssh_auth_ready() {
  local output
  output="$(ssh -o BatchMode=yes -T "git@$PRIMARY_GITHUB_HOST" 2>&1 || true)"
  [[ "$output" == *"successfully authenticated"* ]]
}

clone_enabled_repos() {
  if [[ ! -f "$REPO_MANIFEST_PATH" ]]; then
    return
  fi

  local enabled_count
  enabled_count="$(jq -r '[.debian[]? | select(.enabled == true)] | length' "$REPO_MANIFEST_PATH")"
  if [[ "$enabled_count" == "0" ]]; then
    return
  fi

  if ! github_ssh_auth_ready; then
    warn "GitHub SSH auth is not ready inside Debian. Add the Debian public key to GitHub, then rerun setup-debian-workspace."
    return
  fi

  jq -c '.debian[]? | select(.enabled == true)' "$REPO_MANIFEST_PATH" | while IFS= read -r repo_entry; do
    repo_name=""
    repo_url=""
    repo_path=""
    repo_name="$(jq -r '.name' <<<"$repo_entry")"
    repo_url="$(jq -r '.url' <<<"$repo_entry")"
    repo_path="$(jq -r '.path' <<<"$repo_entry")"
    repo_path="${repo_path//\$HOME/$HOME}"
    repo_path="${repo_path/#\~/$HOME}"

    if [[ -d "$repo_path/.git" ]]; then
      log "Repo already present, skipping: $repo_name ($repo_path)"
      continue
    fi

    if [[ -e "$repo_path" && ! -d "$repo_path/.git" ]]; then
      printf '%s\n' "Target path exists and is not a Git repo: $repo_path" >&2
      exit 1
    fi

    mkdir -p "$(dirname "$repo_path")"
    log "Cloning $repo_name into $repo_path"
    git clone "$repo_url" "$repo_path"
  done
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    log "VS Code already installed in Debian"
    return
  fi

  local architecture
  architecture="$(dpkg --print-architecture)"

  mkdir -p /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/keyrings/packages.microsoft.gpg
    chmod 644 /etc/apt/keyrings/packages.microsoft.gpg
  fi

  cat > /etc/apt/sources.list.d/vscode.list <<EOF
deb [arch=${architecture} signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF

  apt update
  ensure_package_list "$DEBIAN_VSCODE_PACKAGES"
}

install_azure_cli() {
  if command -v az >/dev/null 2>&1; then
    log "Azure CLI already installed in Debian"
    return
  fi

  ensure_package_list "$DEBIAN_AZURE_PACKAGES"
  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
}

configure_git_and_ssh() {
  git config --global user.name "$DEBIAN_GIT_USER_NAME"
  git config --global user.email "$DEBIAN_GIT_USER_EMAIL"
  git config --global init.defaultBranch main
  git config --global pull.ff only
  git config --global core.editor nano

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    log "Generating Debian SSH key"
    ssh-keygen -q -t ed25519 -C "$DEBIAN_GIT_USER_EMAIL" -f "$HOME/.ssh/id_ed25519" -N "$DEBIAN_SSH_KEY_PASSPHRASE"
  else
    log "Debian SSH key already present"
  fi

  cat > "$HOME/.ssh/config" <<EOF
Host $PRIMARY_GITHUB_HOST
  HostName $PRIMARY_GITHUB_HOST
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
EOF

  chmod 600 "$HOME/.ssh/config"
  ensure_known_host
}

main() {
  log "Updating Debian packages"
  apt update
  apt upgrade -y

  ensure_package_list "$DEBIAN_BASE_PACKAGES"
  ensure_workspace_directories "$DEBIAN_WORKSPACE_DIRS"
  configure_git_and_ssh

  if is_true "$ENABLE_VSCODE_TUNNEL"; then
    install_vscode
  fi

  if is_true "$ENABLE_AZURE_CLI_DEBIAN"; then
    install_azure_cli
  fi

  clone_enabled_repos

  log "Debian provisioning complete"
  log "Debian SSH public key:"
  cat "$HOME/.ssh/id_ed25519.pub"
}

main "$@"
