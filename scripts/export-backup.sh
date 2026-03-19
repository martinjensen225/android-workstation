#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

copy_with_home_layout() {
  local source_path="$1"
  local backup_root="$2"
  local relative_path destination_parent

  relative_path="${source_path#$HOME/}"
  destination_parent="$backup_root/home/$(dirname "$relative_path")"
  mkdir -p "$destination_parent"
  cp -a "$source_path" "$destination_parent/"
}

main() {
  assert_termux
  load_environment
  require_command jq

  local timestamp_value export_root metadata_root archive_path
  timestamp_value="$(date '+%Y%m%d-%H%M%S')"
  export_root="$BACKUP_EXPORT_ROOT/$timestamp_value"
  metadata_root="$export_root/metadata"

  mkdir -p "$export_root/home"
  mkdir -p "$metadata_root"

  jq -r '.backup.paths[]' "$BOOTSTRAP_MANIFEST_PATH" | while IFS= read -r raw_path; do
    resolved_path=""
    resolved_path="$(expand_home_tokens "$raw_path")"
    if [[ -e "$resolved_path" ]]; then
      copy_with_home_layout "$resolved_path" "$export_root"
    fi
  done

  if [[ -f "$REPO_MANIFEST_PATH" ]]; then
    cp -a "$REPO_MANIFEST_PATH" "$metadata_root/repos.json"
  fi

  pkg list-installed > "$metadata_root/termux-packages.txt"
  git config --global --list > "$metadata_root/git-config.txt"
  if [[ -f "$SSH_KEY_PATH.pub" ]]; then
    cp -a "$SSH_KEY_PATH.pub" "$metadata_root/$(basename "$SSH_KEY_PATH").pub"
  fi

  archive_path="$BACKUP_EXPORT_ROOT/$timestamp_value.tar.gz"
  tar -czf "$archive_path" -C "$BACKUP_EXPORT_ROOT" "$timestamp_value"

  log "Backup exported to $archive_path"
  log "Unpacked snapshot kept at $export_root"
}

main "$@"
