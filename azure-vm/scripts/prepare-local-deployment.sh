#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AZURE_VM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${AZURE_VM_DIR}/.." && pwd)"

SOURCE_PARAMETERS_FILE="${AZURE_VM_DIR}/parameters/westeurope.example.bicepparam"
TARGET_PARAMETERS_FILE="${AZURE_VM_DIR}/parameters/westeurope.local.bicepparam"
SSH_KEY_PATH="${HOME}/.ssh/id_ed25519_android_workstation_vm"
ADMIN_USERNAME="martin"
TUNNEL_NAME="android-workstation-weu"
OVERWRITE_PARAMETERS_FILE="false"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Prepares a local parameter file and fallback SSH key for the Azure VM deployment flow.
This is designed to work from a Linux shell such as Termux + proot-distro, WSL, or Cloud Shell.

Options:
  --parameters-file <path>   Write the local parameter file to this path.
  --ssh-key-path <path>      Generate or reuse the fallback SSH key at this path.
  --admin-username <name>    Set adminUsername in the local parameter file.
  --tunnel-name <name>       Set vscodeTunnelName in the local parameter file.
  --overwrite                Recopy the example parameter file before patching values.
  --help                     Show this help text.
EOF
}

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf '%s\n' "Required command not found: ${command_name}"
    exit 1
  fi
}

escape_bicep_string() {
  local raw_value="$1"
  printf '%s' "${raw_value//\'/''}"
}

upsert_param_line() {
  local file_path="$1"
  local parameter_name="$2"
  local rendered_value="$3"
  local temp_file

  temp_file="$(mktemp)"

  awk -v parameter_name="${parameter_name}" -v rendered_value="${rendered_value}" '
    BEGIN {
      replacement = "param " parameter_name " = " rendered_value
      updated = 0
    }
    $0 ~ "^param " parameter_name " = " {
      print replacement
      updated = 1
      next
    }
    {
      print
    }
    END {
      if (updated == 0) {
        print replacement
      }
    }
  ' "${file_path}" > "${temp_file}"

  mv "${temp_file}" "${file_path}"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --parameters-file)
        TARGET_PARAMETERS_FILE="$2"
        shift 2
        ;;
      --ssh-key-path)
        SSH_KEY_PATH="$2"
        shift 2
        ;;
      --admin-username)
        ADMIN_USERNAME="$2"
        shift 2
        ;;
      --tunnel-name)
        TUNNEL_NAME="$2"
        shift 2
        ;;
      --overwrite)
        OVERWRITE_PARAMETERS_FILE="true"
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        printf '%s\n' "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

prepare_parameters_file() {
  local target_directory

  target_directory="$(dirname "${TARGET_PARAMETERS_FILE}")"
  install -d -m 0755 "${target_directory}"
  target_directory="$(cd "${target_directory}" && pwd)"
  TARGET_PARAMETERS_FILE="${target_directory}/$(basename "${TARGET_PARAMETERS_FILE}")"

  if [[ ! -f "${TARGET_PARAMETERS_FILE}" || "${OVERWRITE_PARAMETERS_FILE}" == "true" ]]; then
    cp "${SOURCE_PARAMETERS_FILE}" "${TARGET_PARAMETERS_FILE}"
  fi
}

ensure_ssh_key_pair() {
  install -d -m 0700 "$(dirname "${SSH_KEY_PATH}")"

  if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    ssh-keygen -t ed25519 -C "${ADMIN_USERNAME}@android-workstation-vm" -f "${SSH_KEY_PATH}" -N ''
  fi
}

apply_local_values() {
  local public_key
  local escaped_public_key
  local escaped_admin_username
  local escaped_tunnel_name

  public_key="$(<"${SSH_KEY_PATH}.pub")"
  escaped_public_key="$(escape_bicep_string "${public_key}")"
  escaped_admin_username="$(escape_bicep_string "${ADMIN_USERNAME}")"
  escaped_tunnel_name="$(escape_bicep_string "${TUNNEL_NAME}")"

  upsert_param_line "${TARGET_PARAMETERS_FILE}" "adminUsername" "'${escaped_admin_username}'"
  upsert_param_line "${TARGET_PARAMETERS_FILE}" "adminSshPublicKey" "'${escaped_public_key}'"
  upsert_param_line "${TARGET_PARAMETERS_FILE}" "vscodeTunnelName" "'${escaped_tunnel_name}'"
}

print_next_steps() {
  cat <<EOF

Prepared local deployment inputs.

Repo root: ${REPO_ROOT}
Local parameter file: ${TARGET_PARAMETERS_FILE}
Fallback SSH private key: ${SSH_KEY_PATH}
Fallback SSH public key: ${SSH_KEY_PATH}.pub

Suggested next steps from your phone or another admin shell:

  1. Sign in:
     az login --use-device-code

  2. Review the deployment:
     az deployment sub what-if \\
       --location westeurope \\
       --template-file ${AZURE_VM_DIR}/main.bicep \\
       --parameters @${TARGET_PARAMETERS_FILE}

  3. Deploy after the what-if looks right:
     az deployment sub create \\
       --location westeurope \\
       --template-file ${AZURE_VM_DIR}/main.bicep \\
       --parameters @${TARGET_PARAMETERS_FILE}

  4. If you need a one-time admin shell to register the VS Code tunnel, temporarily set
     adminSshSourceCidrs in ${TARGET_PARAMETERS_FILE} to your current public IP /32, run
     what-if again, redeploy, SSH in, run android-workstation-tunnel-register, and then
     remove the CIDR again.
EOF
}

main() {
  parse_arguments "$@"
  require_command ssh-keygen
  require_command awk
  prepare_parameters_file
  ensure_ssh_key_pair
  apply_local_values
  print_next_steps
}

main "$@"
