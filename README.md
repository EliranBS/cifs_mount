# CIFS Mount Maintenance

## Overview

This repository provides a Bash script for Ubuntu Linux that continuously maintains a CIFS mount from a Windows host. If the mount is disconnected or unavailable, the script automatically attempts to mount it again.

The project is designed for home labs, small office servers, and Linux hosts that depend on a persistent Windows network share.

---

## What the script does

- Validates required system commands exist.
- Validates that the CIFS credentials file is readable.
- Creates the local mount directory if needed.
- Re-checks mount status on a fixed interval.
- Re-mounts the share when it is not mounted.
- Writes timestamped logs to a log file and stdout.

---

## Prerequisites

1. Ubuntu Linux machine (or similar distribution with CIFS support).
2. `cifs-utils` package installed:

   ```bash
   sudo apt update
   sudo apt install -y cifs-utils
   ```

3. `sudo` access (or root) for mounting and creating system directories.
4. A reachable Windows/SMB host and shared folder.

---

## Configuration

The script supports environment-based configuration (recommended for systemd) and internal defaults.

### Default values

- `WINDOWS_HOST=192.168.1.100`
- `WINDOWS_SHARE=SharedFolder`
- `MOUNT_POINT=/mnt/windows_share`
- `CREDENTIALS_FILE=/etc/smbcredentials/windows_share.creds`
- `LOG_FILE=/var/log/cifs_remount.log`
- `CHECK_INTERVAL=60`
- `CIFS_OPTIONS=credentials=<CREDENTIALS_FILE>,iocharset=utf8,vers=3.0`

### Overriding values

You can override any setting via environment variables before running:

```bash
export WINDOWS_HOST="192.168.1.50"
export WINDOWS_SHARE="TeamShare"
export MOUNT_POINT="/mnt/team_share"
sudo ./maintain_cifs_mount.sh
```

---

## Creating the credentials file

1. Create credentials directory:

   ```bash
   sudo mkdir -p /etc/smbcredentials
   ```

2. Create credentials file:

   ```bash
   sudo bash -c 'cat <<EOF > /etc/smbcredentials/windows_share.creds
   username=<CIFS_USER>
   password=<CIFS_PASS>
   domain=<OPTIONAL_DOMAIN>
   EOF'
   ```

3. Restrict file permissions:

   ```bash
   sudo chmod 600 /etc/smbcredentials/windows_share.creds
   ```

---

## Script options

```bash
./maintain_cifs_mount.sh [options]
```

Available options:

- `--once` : Perform one check/mount attempt and exit.
- `--dry-run` : Print actions without changing system state.
- `-h`, `--help` : Show usage information.

Examples:

```bash
# One-time check
sudo ./maintain_cifs_mount.sh --once

# Show what would happen, no system changes
sudo ./maintain_cifs_mount.sh --dry-run --once
```

---

## Installation

1. Copy script to a system path:

   ```bash
   sudo mkdir -p /usr/local/bin
   sudo cp maintain_cifs_mount.sh /usr/local/bin/maintain_cifs_mount.sh
   sudo chmod +x /usr/local/bin/maintain_cifs_mount.sh
   ```

2. Optional: create log file in advance:

   ```bash
   sudo touch /var/log/cifs_remount.log
   sudo chmod 644 /var/log/cifs_remount.log
   ```

---

## Running at boot with systemd (recommended)

Create `/etc/systemd/system/maintain_cifs_mount.service`:

```ini
[Unit]
Description=Maintain CIFS Mount for Windows Share
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/maintain_cifs_mount.sh
Restart=always
RestartSec=10
User=root
Environment=WINDOWS_HOST=192.168.1.100
Environment=WINDOWS_SHARE=SharedFolder
Environment=MOUNT_POINT=/mnt/windows_share
Environment=CREDENTIALS_FILE=/etc/smbcredentials/windows_share.creds
Environment=CHECK_INTERVAL=60

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable maintain_cifs_mount.service
sudo systemctl start maintain_cifs_mount.service
sudo systemctl status maintain_cifs_mount.service
```

---

## Logging and verification

Watch logs:

```bash
sudo tail -f /var/log/cifs_remount.log
```

Check mount status manually:

```bash
mountpoint /mnt/windows_share && echo "Mounted"
```

---

## Notes and limitations

- This script assumes `sudo` can execute mount operations for the running user (or it is run as root).
- Network outages, DNS issues, firewall restrictions, or SMB protocol mismatches can prevent mounting.
- If your server needs another SMB version, update `vers=...` in `CIFS_OPTIONS`.
