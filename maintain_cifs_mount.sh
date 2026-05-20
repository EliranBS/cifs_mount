#!/usr/bin/env bash
#
# Script Name: maintain_cifs_mount.sh
# Description: Continuously ensures that a CIFS share from a Windows host
#              is mounted at a specified mount point on Ubuntu Linux.
#              If the mount disappears, the script will attempt to re-mount it.

set -u

# Variables (can be overridden by environment variables)
WINDOWS_HOST="${WINDOWS_HOST:-192.168.1.100}"         # IP or hostname of the Windows machine
WINDOWS_SHARE="${WINDOWS_SHARE:-SharedFolder}"        # Name of the shared folder on Windows
MOUNT_POINT="${MOUNT_POINT:-/mnt/windows_share}"      # Local mount point on Ubuntu
CREDENTIALS_FILE="${CREDENTIALS_FILE:-/etc/smbcredentials/windows_share.creds}"
LOG_FILE="${LOG_FILE:-/var/log/cifs_remount.log}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"                # Seconds to wait between mount checks
CIFS_OPTIONS="${CIFS_OPTIONS:-credentials=${CREDENTIALS_FILE},iocharset=utf8,vers=3.0}"

RUN_ONCE=false
DRY_RUN=false

usage() {
    cat <<USAGE
Usage: $0 [options]

Options:
  --once               Run a single check/mount attempt and exit.
  --dry-run            Print what would be done without mounting.
  -h, --help           Show this help message.

Environment overrides:
  WINDOWS_HOST, WINDOWS_SHARE, MOUNT_POINT, CREDENTIALS_FILE,
  LOG_FILE, CHECK_INTERVAL, CIFS_OPTIONS
USAGE
}

# --------------------------------------------------------------------------------
# Function: log_msg
# Logs timestamped messages to both STDOUT and the LOG_FILE
# --------------------------------------------------------------------------------
log_msg() {
    local message="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    if [[ -n "${LOG_FILE}" ]]; then
        echo "${timestamp} - ${message}" | tee -a "${LOG_FILE}"
    else
        echo "${timestamp} - ${message}"
    fi
}

# --------------------------------------------------------------------------------
# Function: run_cmd
# Runs commands or prints them in dry-run mode.
# --------------------------------------------------------------------------------
run_cmd() {
    if [[ "${DRY_RUN}" == true ]]; then
        log_msg "DRY-RUN: $*"
        return 0
    fi

    "$@"
}

# --------------------------------------------------------------------------------
# Function: check_dependencies
# Verifies required commands are available.
# --------------------------------------------------------------------------------
check_dependencies() {
    local missing=0
    for cmd in mount mountpoint grep date tee; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            echo "ERROR: Required command not found: ${cmd}"
            missing=1
        fi
    done

    if [[ "${missing}" -ne 0 ]]; then
        exit 1
    fi
}

# --------------------------------------------------------------------------------
# Function: mount_share
# Attempts to mount the CIFS share. Returns 0 on success, non-zero on failure.
# --------------------------------------------------------------------------------
mount_share() {
    log_msg "Attempting to mount //${WINDOWS_HOST}/${WINDOWS_SHARE} at ${MOUNT_POINT}"
    run_cmd sudo mount -t cifs "//${WINDOWS_HOST}/${WINDOWS_SHARE}" "${MOUNT_POINT}" -o "${CIFS_OPTIONS}"
    return $?
}

# --------------------------------------------------------------------------------
# Function: check_credentials
# Verifies that the credentials file exists and is readable.
# --------------------------------------------------------------------------------
check_credentials() {
    if [[ ! -r "${CREDENTIALS_FILE}" ]]; then
        echo "ERROR: Credentials file ${CREDENTIALS_FILE} missing or not readable."
        echo "Create it with:"
        echo "  sudo bash -c 'cat <<EOF > ${CREDENTIALS_FILE}
username=<CIFS_USER>
password=<CIFS_PASS>
domain=<OPTIONAL_DOMAIN>
EOF'"
        echo "Then run: sudo chmod 600 ${CREDENTIALS_FILE}"
        exit 1
    fi
}

is_mounted() {
    mountpoint -q "${MOUNT_POINT}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --once)
                RUN_ONCE=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

main_loop() {
    while true; do
        if is_mounted; then
            log_msg "Share already mounted at ${MOUNT_POINT}."
            if [[ "${RUN_ONCE}" == true ]]; then
                return 0
            fi
            sleep "${CHECK_INTERVAL}"
            continue
        fi

        if mount_share; then
            log_msg "Mount succeeded."
        else
            log_msg "ERROR: Mount failed."
        fi

        if [[ "${RUN_ONCE}" == true ]]; then
            return 0
        fi

        sleep "${CHECK_INTERVAL}"
    done
}

parse_args "$@"
check_dependencies

if [[ ! -d "${MOUNT_POINT}" ]]; then
    run_cmd sudo mkdir -p "${MOUNT_POINT}"
    run_cmd sudo chown "$(id -u):$(id -g)" "${MOUNT_POINT}"
fi

check_credentials

log_msg "===== Starting CIFS mount maintenance loop ====="
main_loop
