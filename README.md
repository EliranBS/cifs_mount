# CIFS Mount Maintenance

## Overview

This README describes how to set up and run a Bash script on Ubuntu Linux that continuously maintains a CIFS mount from a Windows host. Whenever the CIFS mount “disappears,” the script will automatically attempt to re-mount the share. The instructions cover:

- Prerequisites
- Script variables and configuration
- Creating the credentials file
- Installing and making the script executable
- Running the script at boot via systemd (recommended) or cron
- Logging behavior

By following these steps, you will ensure that the Windows share remains mounted at a designated mount point at all times.

---

## Prerequisites

1. **Ubuntu Linux machine** (any version that supports `cifs-utils`).
2. **cifs-utils** package installed:
   ```bash
   sudo apt update
   sudo apt install -y cifs-utils
   ```
3. **Root privileges** (or `sudo` access) to create directories under `/etc`, set file permissions, and configure systemd or cron.
4. **A Windows host** with a shared folder accessible via CIFS/SMB. You will need:
   - Windows host IP or hostname
   - Share name
   - Windows username and password (and optional domain/workgroup)

---

## Script Configuration

1. **Script path**
   Decide where you want to place the Bash script. For example:
   ```bash
   /usr/local/bin/maintain_cifs_mount.sh
   ```
3. **Variables in the script**
   Open `maintain_cifs_mount.sh` in a text editor and adjust the following      variables at the top:
   ```bash
   # IP or hostname of the Windows machine
   WINDOWS_HOST="192.168.1.100"

   # Name of the shared folder on Windows
   WINDOWS_SHARE="SharedFolder"

   # Local mount point on Ubuntu (must match the directory you create)
   MOUNT_POINT="/mnt/windows_share"

   # Path to the credentials file (created later)
   CREDENTIALS_FILE="/etc/smbcredentials/windows_share.creds"

   # Path to the log file
   LOG_FILE="/var/log/cifs_remount.log"

   # Time interval (in seconds) between mount checks
   CHECK_INTERVAL=60

   # CIFS mount options (credentials file, character set, SMB version)
   CIFS_OPTIONS="credentials=${CREDENTIALS_FILE},iocharset=utf8,vers=3.0"

   ```
   - **WINDOWS_HOST:** Replace with the IP address or hostname of your Windows server.
   - **WINDOWS_SHARE:** Replace with the exact share name on the Windows side.
   - **MOUNT_POINT:** Replace with the directory on Ubuntu where you want the share to be mounted.
   - **CREDENTIALS_FILE:** This file will hold the Windows login (username, password, domain).
   - **LOG_FILE:** Any messages (success or failure) will be appended here.
   - **CHECK_INTERVAL:** Interval (in seconds) between successive mount checks. Adjust as needed.
   - **CIFS_OPTIONS:** You can modify vers=3.0 if your Windows server requires a different SMB version (e.g., vers=2.0 or vers=1.0).

---

## Creating the Credentials File
1. Create the directory for credentials (if it does not already exist):
  ```bash
  sudo mkdir -p /etc/smbcredentials
  ```
2. Create the credentials file and insert Windows login details. Run:
   ```bash
   sudo bash -c 'cat <<EOF > /etc/smbcredentials/windows_share.cred
   susername=<CIFS_USER>
   password=<CIFS_PASS>
   domain=<OPTIONAL_DOMAIN>
   EOF'
   ```
   - Replace `<CIFS_USER>` with your Windows username.
   - Replace `<CIFS_PASS>` with your Windows password.
   - Replace `<OPTIONAL_DOMAIN>` with your Windows domain or workgroup. If you are not in a domain, you can omit the `domain=` line or leave it blank.
3. Secure the credentials file so only root can read it:
   ```bash
   sudo chmod 600 /etc/smbcredentials/windows_share.creds
   ```
   This prevents unauthorized users from reading your Windows credentials.

---

## Installing the Script
1. Create or open the target directory for executable scripts (e.g. `/usr/local/bin`):
   ```bash
   sudo mkdir -p /usr/local/bin
   ```
2. Copy the `maintain_cifs_mount.sh` script into the directory.
3. Make the script executable:
   ```bash
   sudo chmod +x /usr/local/bin/maintain_cifs_mount.sh
   ```

---

## Logging

- All activity (attempts to mount, success, failure) is appended to:
  ```bash
  /var/log/cifs_remount.log
  ```
- You can view the log in real time with:
  ```bash
  sudo tail -f /var/log/cifs_remount.log
  ```

---

## Running the Script at Boot

1. Create a systemd service file:
   ```bash
   sudo bash -c 'cat <<EOF > /etc/systemd/system/maintain_cifs_mount.service
   [Unit]
   Description=Maintain CIFS Mount for Windows Share
   After=network-online.target

   [Service]
   Type=simple
   ExecStart=/usr/local/bin/maintain_cifs_mount.sh
   Restart=always
   User=root

   [Install]
   WantedBy=multi-user.target
   EOF'
   ```
2. Reload systemd and enable the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable maintain_cifs_mount.service
   sudo systemctl start maintain_cifs_mount.service
   ```
3. Verify that the service is running:
   ```bash
   sudo systemctl status maintain_cifs_mount.service
   ```
   - The service will now start at every system boot and will automatically restart if the script exits.
  
---

## Usage and Verification
1. Manual Test
   - Run the script manually to verify it mounts the share:
     ```bash
     sudo /usr/local/bin/maintain_cifs_mount.sh
     ```
   - Observe the console output and check `/var/log/cifs_remount.log` for any errors.
   - In a separate terminal, forcibly unmount the share to test recovery:
     ```bash
     sudo umount /mnt/windows_share
     ```
   - Within 60 seconds (or your configured `CHECK_INTERVAL`), the script should detect that the mount is gone and attempt to re-mount it. Verify that the share reappears under `/mnt/windows_share`.
2. Automated Startup
   - Reboot the Ubuntu machine:
     ```bash
     sudo reboot
     ```
   - After boot, confirm that the service is active:
     ```bash
     sudo systemctl status maintain_cifs_mount.service
     ```
   - Verify that `/mnt/windows_share` is mounted:
     ```bash
     mount | grep /mnt/windows_share
     ```
3. Adjusting Parameters
   - If you need to change the Windows host, share name, or mount point, edit `/usr/local/bin/maintain_cifs_mount.sh` and modify the variables under the “Variables” section.
   - If the SMB version on your Windows server is different, change `vers=3.0` in `CIFS_OPTIONS` to the appropriate version (e.g., `vers=2.1`, `vers=2.0`, or `vers=1.0`).
