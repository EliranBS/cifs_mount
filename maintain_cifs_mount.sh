#!/usr/bin/env bash
#
# Script Name: maintain_cifs_mount.sh
# Description: Continuously ensures that a CIFS share from a Windows host
#              is mounted at a specified mount point on Ubuntu Linux.
#              If the mount “disappears,” the script will attempt to re-mount it.
#
# Prerequisites:
#   - cifs-utils package installed (sudo apt install cifs-utils)
#   - A credentials file at /etc/smbcredentials/windows_share.creds with secure permissions
#
# Variables (edit these before first run):
WINDOWS_HOST="192.168.1.100"         # IP or hostname of the Windows machine
WINDOWS_SHARE="SharedFolder"        # Name of the shared folder on Windows
MOUNT_POINT="/mnt/windows_share"    # Local mount point on Ubuntu
CREDENTIALS_FILE="/etc/smbcredentials/windows_share.creds"
LOG_FILE="/var/log/cifs_remount.log"
CHECK_INTERVAL=60                   # Seconds to wait between mount checks
CIFS_OPTIONS="credentials=${CREDENTIALS_FILE},iocharset=utf8,vers=3.0"

# --------------------------------------------------------------------------------
# Function: log_msg
# Logs timestamped messages to both STDOUT and the LOG_FILE
# --------------------------------------------------------------------------------
log_msg() {
    local message="$1"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${timestamp} - ${message}" | tee -a "${LOG_FILE}"
}

# --------------------------------------------------------------------------------
# Function: mount_share
# Attempts to mount the CIFS share. Returns 0 on success, non-zero on failure.
# --------------------------------------------------------------------------------
mount_share() {
    log_msg "Attempting to mount //${WINDOWS_HOST}/${WINDOWS_SHARE} at ${MOUNT_POINT}"
    sudo mount -t cifs "//${WINDOWS_HOST}/${WINDOWS_SHARE}" "${MOUNT_POINT}" -o ${CIFS_OPTIONS}
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

# --------------------------------------------------------------------------------
# Main Script Logic
# --------------------------------------------------------------------------------
# 1. Ensure mount point directory exists
if [[ ! -d "${MOUNT_POINT}" ]]; then
    sudo mkdir -p "${MOUNT_POINT}"
    sudo chown "$(id -u):$(id -g)" "${MOUNT_POINT}"
fi

# 2. Verify credentials file
check_credentials

log_msg "===== Starting CIFS mount maintenance loop ====="

# 3. Infinite loop: check and mount if necessary
while true; do
    # Check if the share is already mounted
    if mount | grep -qE "[[:space:]]${MOUNT_POINT}[[:space:]]"; then
        # Already mounted
        sleep "${CHECK_INTERVAL}"
        continue
    fi

    # Not mounted: attempt to mount
    if mount_share; then
        log_msg "Mount succeeded."
    else
        log_msg "ERROR: Mount failed."
    fi

    # Wait before next check
    sleep "${CHECK_INTERVAL}"
done
