#!/usr/bin/env bash

set -Eeuo pipefail

INSTALL_AZURE_CLI="${INSTALL_AZURE_CLI:-true}"
INSTALL_TERRAFORM="${INSTALL_TERRAFORM:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
INSTALL_GITHUB_CLI="${INSTALL_GITHUB_CLI:-false}"
TARGET_USER="${TARGET_USER:-${SUDO_USER:-$USER}}"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf '%s\n' "Run this script with sudo so it can install packages and enable linger."
    exit 1
  fi
}

install_base_packages() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    wget \
    gpg \
    apt-transport-https \
    lsb-release \
    git \
    openssh-client \
    jq \
    ripgrep \
    tmux \
    unzip \
    zip \
    build-essential \
    python3 \
    python3-pip
}

install_azure_cli() {
  if [[ "${INSTALL_AZURE_CLI}" != "true" ]]; then
    return
  fi

  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
}

install_hashicorp_repo() {
  if [[ "${INSTALL_TERRAFORM}" != "true" ]]; then
    return
  fi

  install -m 0755 -d /usr/share/keyrings
  wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
  chmod 0644 /usr/share/keyrings/hashicorp-archive-keyring.gpg
  . /etc/os-release
  printf '%s\n' "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y terraform
}

install_vscode() {
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/keyrings/packages.microsoft.gpg
  chmod 0644 /etc/apt/keyrings/packages.microsoft.gpg
  printf '%s\n' "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y code
}

install_github_cli() {
  if [[ "${INSTALL_GITHUB_CLI}" != "true" ]]; then
    return
  fi

  DEBIAN_FRONTEND=noninteractive apt-get install -y gh
}

install_docker() {
  if [[ "${INSTALL_DOCKER}" != "true" ]]; then
    return
  fi

  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose-plugin
  usermod -aG docker "${TARGET_USER}"
}

print_next_steps() {
  cat <<EOF

Bootstrap complete.

Recommended next steps as ${TARGET_USER}:

  1. Sign in to Azure CLI if you want az/bicep on the VM:
     az login --use-device-code
     az bicep install

  2. Start the VS Code tunnel once interactively:
     code tunnel

  3. After the tunnel is authenticated, keep it available between logins:
     sudo loginctl enable-linger ${TARGET_USER}
     code tunnel service install

  4. If you installed Docker, start a new shell so the docker group membership is picked up.

  5. From your phone browser, open the VS Code tunnel URL shown by the tunnel command.

This script deliberately does not automate Microsoft sign-in for the tunnel.
EOF
}

main() {
  require_root
  install_base_packages
  install_azure_cli
  install_hashicorp_repo
  install_vscode
  install_github_cli
  install_docker
  print_next_steps
}

main "$@"
