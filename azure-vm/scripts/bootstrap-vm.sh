#!/usr/bin/env bash

set -Eeuo pipefail

BOOTSTRAP_TARGET_USER_DEFAULT="__BOOTSTRAP_TARGET_USER__"
BOOTSTRAP_INSTALL_AZURE_CLI_DEFAULT="__BOOTSTRAP_INSTALL_AZURE_CLI__"
BOOTSTRAP_INSTALL_BICEP_DEFAULT="__BOOTSTRAP_INSTALL_BICEP__"
BOOTSTRAP_INSTALL_TERRAFORM_DEFAULT="__BOOTSTRAP_INSTALL_TERRAFORM__"
BOOTSTRAP_INSTALL_GITHUB_CLI_DEFAULT="__BOOTSTRAP_INSTALL_GITHUB_CLI__"
BOOTSTRAP_INSTALL_DOCKER_DEFAULT="__BOOTSTRAP_INSTALL_DOCKER__"
BOOTSTRAP_TUNNEL_NAME_DEFAULT="__BOOTSTRAP_TUNNEL_NAME__"

BOOTSTRAP_STATE_DIR="/var/lib/android-workstation"
BOOTSTRAP_LOG_PATH="/var/log/android-workstation-bootstrap.log"
BOOTSTRAP_CONFIG_DIR="/etc/android-workstation"
BOOTSTRAP_CONFIG_PATH="${BOOTSTRAP_CONFIG_DIR}/vscode-tunnel.env"

normalize_placeholder() {
  local value="$1"

  if [[ "${value}" == __BOOTSTRAP_*__ ]]; then
    printf ''
    return
  fi

  printf '%s' "${value}"
}

normalize_bool() {
  local value="${1,,}"

  case "${value}" in
    true|1|yes|y|on)
      printf 'true'
      ;;
    false|0|no|n|off|'')
      printf 'false'
      ;;
    *)
      printf '%s\n' "Unsupported boolean value: ${1}" >&2
      exit 1
      ;;
  esac
}

resolve_default_bool() {
  local placeholder_value="$1"
  local fallback_value="$2"
  local normalized_value

  normalized_value="$(normalize_placeholder "${placeholder_value}")"
  if [[ -z "${normalized_value}" ]]; then
    normalized_value="${fallback_value}"
  fi

  normalize_bool "${normalized_value}"
}

BOOTSTRAP_TARGET_USER_RESOLVED="$(normalize_placeholder "${BOOTSTRAP_TARGET_USER_DEFAULT}")"
BOOTSTRAP_TUNNEL_NAME_RESOLVED="$(normalize_placeholder "${BOOTSTRAP_TUNNEL_NAME_DEFAULT}")"

INSTALL_AZURE_CLI="${INSTALL_AZURE_CLI:-$(resolve_default_bool "${BOOTSTRAP_INSTALL_AZURE_CLI_DEFAULT}" "true")}"
INSTALL_BICEP="${INSTALL_BICEP:-$(resolve_default_bool "${BOOTSTRAP_INSTALL_BICEP_DEFAULT}" "true")}"
INSTALL_TERRAFORM="${INSTALL_TERRAFORM:-$(resolve_default_bool "${BOOTSTRAP_INSTALL_TERRAFORM_DEFAULT}" "true")}"
INSTALL_GITHUB_CLI="${INSTALL_GITHUB_CLI:-$(resolve_default_bool "${BOOTSTRAP_INSTALL_GITHUB_CLI_DEFAULT}" "false")}"
INSTALL_DOCKER="${INSTALL_DOCKER:-$(resolve_default_bool "${BOOTSTRAP_INSTALL_DOCKER_DEFAULT}" "false")}"
TARGET_USER="${TARGET_USER:-${BOOTSTRAP_TARGET_USER_RESOLVED:-${SUDO_USER:-$USER}}}"
TUNNEL_NAME="${TUNNEL_NAME:-${BOOTSTRAP_TUNNEL_NAME_RESOLVED:-$(hostname -s)}}"

TARGET_HOME=""
TARGET_GROUP=""

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf '%s\n' "Run this script with sudo or as root."
    exit 1
  fi
}

setup_logging() {
  install -m 0755 -d "${BOOTSTRAP_STATE_DIR}" "$(dirname "${BOOTSTRAP_LOG_PATH}")"
  touch "${BOOTSTRAP_LOG_PATH}"
  chmod 0644 "${BOOTSTRAP_LOG_PATH}"
  exec > >(tee -a "${BOOTSTRAP_LOG_PATH}") 2>&1
}

mark_failure() {
  local line_number="$1"
  printf '%s\n' "Bootstrap failed at line ${line_number}. Review ${BOOTSTRAP_LOG_PATH} for details."
  printf '%s\n' "$(date -u +%FT%TZ) failed at line ${line_number}" > "${BOOTSTRAP_STATE_DIR}/bootstrap.failed"
}

resolve_target_user_context() {
  local passwd_entry

  passwd_entry="$(getent passwd "${TARGET_USER}" || true)"
  if [[ -z "${passwd_entry}" ]]; then
    printf '%s\n' "Target user '${TARGET_USER}' does not exist on this VM."
    exit 1
  fi

  TARGET_HOME="$(printf '%s' "${passwd_entry}" | cut -d: -f6)"
  TARGET_GROUP="$(id -gn "${TARGET_USER}")"
}

install_base_packages() {
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    openssh-client \
    python3 \
    python3-pip \
    ripgrep \
    software-properties-common \
    tmux \
    unzip \
    wget \
    zip
}

install_azure_cli() {
  if [[ "${INSTALL_AZURE_CLI}" != "true" ]]; then
    return
  fi

  curl -sL https://aka.ms/InstallAzureCLIDeb | bash
}

install_bicep_cli() {
  if [[ "${INSTALL_AZURE_CLI}" != "true" || "${INSTALL_BICEP}" != "true" ]]; then
    return
  fi

  az bicep install
}

install_hashicorp_repo() {
  if [[ "${INSTALL_TERRAFORM}" != "true" ]]; then
    return
  fi

  install -m 0755 -d /usr/share/keyrings
  wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
  chmod 0644 /usr/share/keyrings/hashicorp-archive-keyring.gpg

  # shellcheck disable=SC1091
  . /etc/os-release
  printf '%s\n' "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/hashicorp.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y terraform
}

install_vscode_cli() {
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

prepare_target_workspace() {
  install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_GROUP}" \
    "${TARGET_HOME}/workspaces" \
    "${TARGET_HOME}/.config" \
    "${TARGET_HOME}/.config/android-workstation"
}

write_tunnel_configuration() {
  install -d -m 0755 "${BOOTSTRAP_CONFIG_DIR}"

  cat > "${BOOTSTRAP_CONFIG_PATH}" <<EOF
TARGET_USER='${TARGET_USER}'
TARGET_HOME='${TARGET_HOME}'
VSCODE_TUNNEL_NAME='${TUNNEL_NAME}'
EOF
  chmod 0644 "${BOOTSTRAP_CONFIG_PATH}"
}

write_tunnel_register_helper() {
  cat > /usr/local/bin/android-workstation-tunnel-register <<'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

CONFIG_PATH="/etc/android-workstation/vscode-tunnel.env"

if [[ ! -f "${CONFIG_PATH}" ]]; then
  printf '%s\n' "Missing ${CONFIG_PATH}. Run the VM bootstrap first."
  exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_PATH}"

PROVIDER="${1:-microsoft}"
LOGIN_ARGS=()

if [[ -n "${VSCODE_CLI_ACCESS_TOKEN:-}" ]]; then
  LOGIN_ARGS=(--access-token "${VSCODE_CLI_ACCESS_TOKEN}")
elif [[ -n "${VSCODE_CLI_REFRESH_TOKEN:-}" ]]; then
  LOGIN_ARGS=(--refresh-token "${VSCODE_CLI_REFRESH_TOKEN}")
else
  LOGIN_ARGS=(--provider "${PROVIDER}")
fi

printf '%s\n' "Signing the tunnel host into Visual Studio Code..."
code tunnel user login "${LOGIN_ARGS[@]}"

printf '%s\n' "Installing the tunnel service for ${VSCODE_TUNNEL_NAME}..."
code tunnel service install --accept-server-license-terms --name "${VSCODE_TUNNEL_NAME}"

printf '%s\n' "Current tunnel status:"
code tunnel status
EOF
  chmod 0755 /usr/local/bin/android-workstation-tunnel-register
}

write_bootstrap_status_helper() {
  cat > /usr/local/bin/android-workstation-bootstrap-status <<EOF
#!/usr/bin/env bash

set -Eeuo pipefail

if [[ -f '${BOOTSTRAP_STATE_DIR}/bootstrap.complete' ]]; then
  printf '%s\n' "Bootstrap complete: \$(cat '${BOOTSTRAP_STATE_DIR}/bootstrap.complete')"
elif [[ -f '${BOOTSTRAP_STATE_DIR}/bootstrap.failed' ]]; then
  printf '%s\n' "Bootstrap failed: \$(cat '${BOOTSTRAP_STATE_DIR}/bootstrap.failed')"
else
  printf '%s\n' 'Bootstrap status marker not found yet.'
fi

printf '%s\n' 'Bootstrap log path: ${BOOTSTRAP_LOG_PATH}'
EOF
  chmod 0755 /usr/local/bin/android-workstation-bootstrap-status
}

enable_user_linger() {
  loginctl enable-linger "${TARGET_USER}"
}

mark_success() {
  printf '%s\n' "$(date -u +%FT%TZ) success" > "${BOOTSTRAP_STATE_DIR}/bootstrap.complete"
  rm -f "${BOOTSTRAP_STATE_DIR}/bootstrap.failed"
}

print_summary() {
  cat <<EOF

Bootstrap complete.

Target user: ${TARGET_USER}
Target home: ${TARGET_HOME}
Tunnel name: ${TUNNEL_NAME}

What is automated:
  - OS package updates and core developer tooling
  - VS Code CLI installation
  - optional Azure CLI, Bicep, Terraform, GitHub CLI, and Docker installation
  - linger enablement so the VS Code tunnel service can survive logout

What still requires a human:
  - one VS Code tunnel sign-in tied to your Microsoft or GitHub account

Run this once as ${TARGET_USER} during your first admin session:
  android-workstation-tunnel-register microsoft

If you intentionally provide a VS Code CLI access token or refresh token in the environment,
the same helper can use it instead of interactive provider login.

Bootstrap log: ${BOOTSTRAP_LOG_PATH}
EOF
}

main() {
  trap 'mark_failure "${LINENO}"' ERR

  require_root
  setup_logging
  resolve_target_user_context
  install_base_packages
  install_azure_cli
  install_bicep_cli
  install_hashicorp_repo
  install_vscode_cli
  install_github_cli
  install_docker
  prepare_target_workspace
  write_tunnel_configuration
  write_tunnel_register_helper
  write_bootstrap_status_helper
  enable_user_linger
  mark_success
  print_summary
}

main "$@"
