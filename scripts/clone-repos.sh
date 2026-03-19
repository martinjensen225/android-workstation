#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

main() {
  assert_termux
  load_environment
  require_command jq

  if [[ ! -f "$REPO_MANIFEST_PATH" ]]; then
    log "Repo manifest not found at $REPO_MANIFEST_PATH. Nothing to clone."
    return 0
  fi

  local enabled_count
  enabled_count="$(jq -r '[.termux[]? | select(.enabled == true)] | length' "$REPO_MANIFEST_PATH")"

  if [[ "$enabled_count" == "0" ]]; then
    log "No enabled Termux repos in $REPO_MANIFEST_PATH"
    return 0
  fi

  if ! github_ssh_auth_ready; then
    warn "GitHub SSH auth is not ready yet. Upload the public key first, then rerun clone-managed-repos."
    return 0
  fi

  jq -c '.termux[]? | select(.enabled == true)' "$REPO_MANIFEST_PATH" | while IFS= read -r repo_entry; do
    repo_name=""
    repo_url=""
    repo_path=""
    repo_name="$(jq -r '.name' <<<"$repo_entry")"
    repo_url="$(jq -r '.url' <<<"$repo_entry")"
    repo_path="$(jq -r '.path' <<<"$repo_entry")"
    repo_path="$(expand_home_tokens "$repo_path")"

    if [[ -d "$repo_path/.git" ]]; then
      log "Repo already present, skipping: $repo_name ($repo_path)"
      continue
    fi

    if [[ -e "$repo_path" && ! -d "$repo_path/.git" ]]; then
      die "Target path exists and is not a Git repo: $repo_path"
    fi

    ensure_directory "$(dirname "$repo_path")"
    log "Cloning $repo_name into $repo_path"
    git clone "$repo_url" "$repo_path"
  done
}

main "$@"
