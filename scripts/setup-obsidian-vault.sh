#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ensure_obsidian_scaffold() {
  jq -r '.obsidian.scaffoldDirectories[]' "$BOOTSTRAP_MANIFEST_PATH" | while IFS= read -r child_directory; do
    ensure_directory "$OBSIDIAN_VAULT_PATH/$child_directory"
  done
}

init_obsidian_repo() {
  ensure_directory "$OBSIDIAN_VAULT_PATH"
  ensure_obsidian_scaffold

  if [[ ! -d "$OBSIDIAN_VAULT_PATH/.git" ]]; then
    log "Initializing local Obsidian Git repo in $OBSIDIAN_VAULT_PATH"
    git -C "$OBSIDIAN_VAULT_PATH" init
    git -C "$OBSIDIAN_VAULT_PATH" branch -M main
  else
    log "Obsidian vault Git repo already initialized"
  fi

  if [[ ! -f "$OBSIDIAN_VAULT_PATH/.gitignore" ]]; then
    render_template "$BUNDLE_ROOT/templates/obsidian.gitignore.template" "$OBSIDIAN_VAULT_PATH/.gitignore" 644
  fi
}

clone_obsidian_repo() {
  ensure_directory "$OBSIDIAN_BASE_DIR"

  if [[ -d "$OBSIDIAN_VAULT_PATH/.git" ]]; then
    log "Obsidian vault repo already present at $OBSIDIAN_VAULT_PATH"
    ensure_obsidian_scaffold
    return 0
  fi

  if [[ -e "$OBSIDIAN_VAULT_PATH" ]]; then
    die "Obsidian vault path exists and is not a Git repo: $OBSIDIAN_VAULT_PATH"
  fi

  if ! github_ssh_auth_ready; then
    warn "GitHub SSH auth is not ready yet. The Obsidian vault clone is deferred until after the public key is added."
    return 0
  fi

  log "Cloning Obsidian vault repo into $OBSIDIAN_VAULT_PATH"
  git clone "$OBSIDIAN_VAULT_REPO_URL" "$OBSIDIAN_VAULT_PATH"
  ensure_obsidian_scaffold
}

main() {
  assert_termux
  load_environment
  require_command jq

  case "$OBSIDIAN_VAULT_MODE" in
    clone)
      clone_obsidian_repo
      ;;
    init)
      init_obsidian_repo
      ;;
    skip)
      ensure_directory "$OBSIDIAN_BASE_DIR"
      log "Skipping Obsidian vault setup by configuration"
      ;;
    *)
      die "Unsupported OBSIDIAN_VAULT_MODE: $OBSIDIAN_VAULT_MODE"
      ;;
  esac
}

main "$@"
