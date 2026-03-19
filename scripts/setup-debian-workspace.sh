#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

main() {
  assert_termux
  load_environment
  require_command jq

  ensure_termux_package proot-distro

  if ! proot-distro login "$DEBIAN_DISTRO" -- true >/dev/null 2>&1; then
    log "Installing $DEBIAN_DISTRO userspace in proot-distro"
    proot-distro install "$DEBIAN_DISTRO"
  else
    log "$DEBIAN_DISTRO userspace already installed"
  fi

  local debian_base_packages debian_workspace_dirs debian_vscode_packages debian_azure_packages
  debian_base_packages="$(jq -r '.debian.basePackages | join(" ")' "$BOOTSTRAP_MANIFEST_PATH")"
  debian_workspace_dirs="$(jq -r '.debian.workspaceDirectories | join("|")' "$BOOTSTRAP_MANIFEST_PATH")"
  debian_vscode_packages="$(jq -r '.debian.vscodePackages | join(" ")' "$BOOTSTRAP_MANIFEST_PATH")"
  debian_azure_packages="$(jq -r '.debian.azurePrerequisitePackages | join(" ")' "$BOOTSTRAP_MANIFEST_PATH")"

  log "Provisioning $DEBIAN_DISTRO userspace"
  proot-distro login "$DEBIAN_DISTRO" -- env \
    PRIMARY_GITHUB_HOST="$PRIMARY_GITHUB_HOST" \
    DEBIAN_GIT_USER_NAME="$DEBIAN_GIT_USER_NAME" \
    DEBIAN_GIT_USER_EMAIL="$DEBIAN_GIT_USER_EMAIL" \
    DEBIAN_SSH_KEY_PASSPHRASE="$DEBIAN_SSH_KEY_PASSPHRASE" \
    ENABLE_VSCODE_TUNNEL="$ENABLE_VSCODE_TUNNEL" \
    ENABLE_AZURE_CLI_DEBIAN="$ENABLE_AZURE_CLI_DEBIAN" \
    DEBIAN_BASE_PACKAGES="$debian_base_packages" \
    DEBIAN_WORKSPACE_DIRS="$debian_workspace_dirs" \
    DEBIAN_VSCODE_PACKAGES="$debian_vscode_packages" \
    DEBIAN_AZURE_PACKAGES="$debian_azure_packages" \
    REPO_MANIFEST_PATH="$REPO_MANIFEST_PATH" \
    /bin/bash -s -- < "$SCRIPT_DIR/debian-provision.sh"
}

main "$@"
