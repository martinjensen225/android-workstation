#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

init_bundle_paths() {
  if [[ -n "${BUNDLE_ROOT:-}" ]]; then
    return
  fi

  BUNDLE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  EXAMPLE_ENV_FILE="$BUNDLE_ROOT/.env.example"
  DEFAULT_ENV_FILE="$BUNDLE_ROOT/.env"
  BOOTSTRAP_MANIFEST_PATH="$BUNDLE_ROOT/manifest/bootstrap.json"
  DEFAULT_REPO_MANIFEST_PATH="$BUNDLE_ROOT/manifest/repos.local.json"
  EXAMPLE_REPO_MANIFEST_PATH="$BUNDLE_ROOT/manifest/repos.example.json"
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*"
}

warn() {
  printf '[%s] WARN: %s\n' "$(timestamp)" "$*" >&2
}

die() {
  printf '[%s] ERROR: %s\n' "$(timestamp)" "$*" >&2
  exit 1
}

bool_is_true() {
  case "${1:-false}" in
    true|TRUE|1|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

assert_termux() {
  [[ -n "${PREFIX:-}" && "$PREFIX" == *"/com.termux/files/usr" ]] || die "Run this inside Termux."
  require_command pkg
  require_command termux-setup-storage
}

load_environment() {
  init_bundle_paths

  local env_file="${1:-$DEFAULT_ENV_FILE}"
  if [[ ! -f "$env_file" ]]; then
    cp "$EXAMPLE_ENV_FILE" "$env_file"
    die "Created $env_file. Fill in the required values and rerun bootstrap."
  fi

  ENV_FILE="$env_file"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a

  apply_defaults
  prepare_local_repo_manifest
}

apply_defaults() {
  PRIMARY_GITHUB_HOST="${PRIMARY_GITHUB_HOST:-github.com}"
  TERMUX_EDITOR="${TERMUX_EDITOR:-nano}"

  WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/code}"
  WORK_REPO_ROOT="${WORK_REPO_ROOT:-$WORKSPACE_ROOT/work}"
  PERSONAL_REPO_ROOT="${PERSONAL_REPO_ROOT:-$WORKSPACE_ROOT/personal}"
  SCRATCH_REPO_ROOT="${SCRATCH_REPO_ROOT:-$WORKSPACE_ROOT/scratch}"

  TERMUX_BIN_ROOT="${TERMUX_BIN_ROOT:-$HOME/bin}"
  BOOTSTRAP_CONFIG_ROOT="${BOOTSTRAP_CONFIG_ROOT:-$HOME/.config/android-workstation}"
  BOOTSTRAP_STATE_ROOT="${BOOTSTRAP_STATE_ROOT:-$HOME/.local/state/android-workstation}"

  CODE_SERVER_BIND_HOST="${CODE_SERVER_BIND_HOST:-127.0.0.1}"
  CODE_SERVER_PORT="${CODE_SERVER_PORT:-8080}"
  CODE_SERVER_BIND_ADDR="${CODE_SERVER_BIND_ADDR:-$CODE_SERVER_BIND_HOST:$CODE_SERVER_PORT}"

  OBSIDIAN_BASE_DIR="${OBSIDIAN_BASE_DIR:-$HOME/storage/shared/Documents/Obsidian}"
  OBSIDIAN_VAULT_NAME="${OBSIDIAN_VAULT_NAME:-work-vault}"
  OBSIDIAN_VAULT_PATH="${OBSIDIAN_VAULT_PATH:-$OBSIDIAN_BASE_DIR/$OBSIDIAN_VAULT_NAME}"
  OBSIDIAN_VAULT_MODE="${OBSIDIAN_VAULT_MODE:-clone}"

  BACKUP_EXPORT_ROOT="${BACKUP_EXPORT_ROOT:-$HOME/storage/shared/Documents/Backups/galaxy-dex-workstation}"

  SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
  SSH_KEY_COMMENT="${SSH_KEY_COMMENT:-${GIT_USER_EMAIL:-}}"
  SSH_KEY_PASSPHRASE="${SSH_KEY_PASSPHRASE:-}"

  ENABLE_CODE_SERVER="${ENABLE_CODE_SERVER:-false}"
  ENABLE_NEOVIM="${ENABLE_NEOVIM:-true}"
  ENABLE_GITHUB_COPILOT_VIM="${ENABLE_GITHUB_COPILOT_VIM:-false}"
  ENABLE_CODEX_TERMUX="${ENABLE_CODEX_TERMUX:-false}"
  ENABLE_DEBIAN_WORKFLOW="${ENABLE_DEBIAN_WORKFLOW:-true}"
  ENABLE_VSCODE_TUNNEL="${ENABLE_VSCODE_TUNNEL:-true}"
  ENABLE_AZURE_CLI_DEBIAN="${ENABLE_AZURE_CLI_DEBIAN:-false}"

  DEBIAN_DISTRO="${DEBIAN_DISTRO:-debian}"
  DEBIAN_GIT_USER_NAME="${DEBIAN_GIT_USER_NAME:-${GIT_USER_NAME:-}}"
  DEBIAN_GIT_USER_EMAIL="${DEBIAN_GIT_USER_EMAIL:-${GIT_USER_EMAIL:-}}"
  DEBIAN_SSH_KEY_PASSPHRASE="${DEBIAN_SSH_KEY_PASSPHRASE:-$SSH_KEY_PASSPHRASE}"

  REPO_MANIFEST_PATH="${REPO_MANIFEST_PATH:-$DEFAULT_REPO_MANIFEST_PATH}"
}

prepare_local_repo_manifest() {
  if [[ "$REPO_MANIFEST_PATH" == "$DEFAULT_REPO_MANIFEST_PATH" && ! -f "$REPO_MANIFEST_PATH" ]]; then
    cp "$EXAMPLE_REPO_MANIFEST_PATH" "$REPO_MANIFEST_PATH"
  fi
}

validate_required_configuration() {
  require_config_value GIT_USER_NAME
  require_config_value GIT_USER_EMAIL

  if bool_is_true "$ENABLE_CODE_SERVER"; then
    require_config_value CODE_SERVER_PASSWORD
  fi

  case "$OBSIDIAN_VAULT_MODE" in
    clone)
      require_config_value OBSIDIAN_VAULT_REPO_URL
      ;;
    init|skip)
      ;;
    *)
      die "OBSIDIAN_VAULT_MODE must be one of: clone, init, skip"
      ;;
  esac
}

require_config_value() {
  local name="$1"
  local value="${!name:-}"

  if [[ -z "$value" || "$value" == REPLACE_ME* || "$value" == *REPLACE_ME* ]]; then
    die "Set $name in $ENV_FILE before running bootstrap."
  fi
}

ensure_directory() {
  mkdir -p "$1"
}

setup_logging() {
  ensure_directory "$BOOTSTRAP_STATE_ROOT/logs"
  LOG_FILE="$BOOTSTRAP_STATE_ROOT/logs/bootstrap-$(date '+%Y%m%d-%H%M%S').log"
  exec > >(tee -a "$LOG_FILE") 2>&1
  log "Logging to $LOG_FILE"
}

ensure_line_once() {
  local file_path="$1"
  local expected_line="$2"

  touch "$file_path"
  if ! grep -Fqx "$expected_line" "$file_path"; then
    printf '%s\n' "$expected_line" >> "$file_path"
  fi
}

render_template() {
  local template_path="$1"
  local destination_path="$2"
  local file_mode="${3:-}"
  local rendered

  rendered="$(<"$template_path")"
  rendered="${rendered//__BUNDLE_ROOT__/$BUNDLE_ROOT}"
  rendered="${rendered//__TERMUX_EDITOR__/$TERMUX_EDITOR}"
  rendered="${rendered//__WORKSPACE_ROOT__/$WORKSPACE_ROOT}"
  rendered="${rendered//__WORK_REPO_ROOT__/$WORK_REPO_ROOT}"
  rendered="${rendered//__PERSONAL_REPO_ROOT__/$PERSONAL_REPO_ROOT}"
  rendered="${rendered//__SCRATCH_REPO_ROOT__/$SCRATCH_REPO_ROOT}"
  rendered="${rendered//__OBSIDIAN_VAULT_PATH__/$OBSIDIAN_VAULT_PATH}"
  rendered="${rendered//__OBSIDIAN_VAULT_NAME__/$OBSIDIAN_VAULT_NAME}"
  rendered="${rendered//__CODE_SERVER_BIND_ADDR__/$CODE_SERVER_BIND_ADDR}"
  rendered="${rendered//__CODE_SERVER_PASSWORD__/${CODE_SERVER_PASSWORD:-}}"
  rendered="${rendered//__DEBIAN_DISTRO__/$DEBIAN_DISTRO}"
  rendered="${rendered//__PRIMARY_GITHUB_HOST__/$PRIMARY_GITHUB_HOST}"
  rendered="${rendered//__BACKUP_EXPORT_ROOT__/$BACKUP_EXPORT_ROOT}"
  rendered="${rendered//__SSH_KEY_PATH__/$SSH_KEY_PATH}"

  printf '%s\n' "$rendered" > "$destination_path"

  if [[ -n "$file_mode" ]]; then
    chmod "$file_mode" "$destination_path"
  fi
}

expand_home_tokens() {
  local raw_path="$1"
  raw_path="${raw_path//\$HOME/$HOME}"
  raw_path="${raw_path/#\~/$HOME}"
  printf '%s' "$raw_path"
}

ensure_termux_package() {
  local package_name="$1"
  if dpkg -s "$package_name" >/dev/null 2>&1; then
    log "Termux package already installed: $package_name"
    return
  fi

  log "Installing Termux package: $package_name"
  pkg install -y "$package_name"
}

ensure_known_host() {
  local known_hosts_path="$HOME/.ssh/known_hosts"
  touch "$known_hosts_path"
  chmod 600 "$known_hosts_path"

  if ! ssh-keygen -F "$PRIMARY_GITHUB_HOST" -f "$known_hosts_path" >/dev/null 2>&1; then
    log "Adding $PRIMARY_GITHUB_HOST to known_hosts"
    ssh-keyscan -H "$PRIMARY_GITHUB_HOST" >> "$known_hosts_path"
  fi
}

github_ssh_auth_ready() {
  local output
  output="$(ssh -o BatchMode=yes -T "git@$PRIMARY_GITHUB_HOST" 2>&1 || true)"
  [[ "$output" == *"successfully authenticated"* ]]
}
