#!/bin/bash

# ==============================================================================
#           Ubuntu 24.04 Server Initial Setup & Hardening Script
#
#  This script performs the following actions:
#  1. Sets up the shell for verbose and safe execution.
#  2. Updates and upgrades all system packages non-interactively.
#  3. Installs and configures UFW (Uncomplicated Firewall) to allow SSH.
#  4. Installs and hardens SSH access using Fail2ban to prevent brute-force attacks.
#  5. Installs Docker Engine and Docker Compose for containerization.
#  6. Installs the lightweight XFCE Desktop Environment.
#  7. Installs the X2Go Server for efficient remote desktop access.
#
#  Designed for a fresh Ubuntu 24.04 installation.
#
#  Usage:
#  - Make the script executable: chmod +x setup_server.sh
#  - Run with sudo:           sudo ./setup_server.sh
# ==============================================================================

# --- Script Configuration and Safety ---

# Exit immediately if a command exits with a non-zero status. This prevents
# errors from having cascading effects.
set -e

# Treat unset variables as an error when substituting. This catches typos
# in variable names.
set -u

# Print each command to the terminal before executing it. This provides a
# verbose trace of what the script is doing.
set -x

# --- Check for Root Privileges ---
# The script needs to install packages and modify system configuration,
# which requires root access.
if [[ $(id -u) -ne 0 ]]; then
  echo "This script must be run as root or with sudo privileges. Aborting."
  exit 1
fi

# --- Announce Start ---
echo "================================================================================"
echo "Starting Ubuntu 24.04 Server Initialization..."
echo "Timestamp: $(date)"
echo "================================================================================"
# A brief pause to allow the user to see the initial message.
sleep 3

# --- Step 1: System Update and Upgrade ---
echo ">>> STEP 1: Performing full system update and upgrade..."
# Set the Debconf frontend to noninteractive to prevent pop-ups during installations.
export DEBIAN_FRONTEND=noninteractive
# Resynchronize the package index files from their sources.
apt-get update
# Perform a non-interactive full upgrade, automatically handling config file changes.
apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
# Remove packages that were automatically installed to satisfy dependencies but are no longer needed.
apt-get -y autoremove
echo ">>> System upgrade complete."
sleep 2

# --- Step 2: Install Essential Packages and Configure Firewall ---
echo ">>> STEP 2: Installing essential tools and configuring UFW Firewall..."
apt-get install -y ufw curl wget gnupg lsb-release

# Configure UFW (Uncomplicated Firewall) for basic security.
echo "Configuring Firewall rules..."
# Set default policies: deny all incoming, allow all outgoing.
ufw default deny incoming
ufw default allow outgoing

# IMPORTANT: Allow SSH connections on its standard port (22).
# Without this rule, the firewall would block your SSH access upon activation.
ufw allow ssh

# Enable the firewall. The 'yes' command is piped to automatically confirm
# the action, preventing the script from hanging.
yes | ufw enable

echo "Firewall enabled. Current status:"
ufw status verbose
echo ">>> Firewall configuration complete."
sleep 2

# --- Step 3: Harden SSH with Fail2ban ---
echo ">>> STEP 3: Installing and configuring Fail2ban to prevent brute-force attacks..."
apt-get install -y fail2ban

# Create a local jail configuration to override defaults. This file will not be
# overwritten by package updates.
echo "Creating /etc/fail2ban/jail.local for custom settings..."
cat <<EOF | tee /etc/fail2ban/jail.local
[DEFAULT]
# Ban hosts for one hour.
bantime = 1h
# An IP is banned if it has generated "maxretry" during the last "findtime".
findtime = 10m
maxretry = 5

# Override settings for the SSH daemon jail.
[sshd]
# Enable this specific jail.
enabled = true
# Stricter rule: ban after 3 failed login attempts.
maxretry = 3
EOF

# Restart and enable Fail2ban to apply the new configuration and ensure it
# starts on boot.
systemctl restart fail2ban
systemctl enable fail2ban

echo "Fail2ban has been configured and started. Current status:"
# Check the service status without using a pager for non-interactive viewing.
systemctl status fail2ban --no-pager
# Use the fail2ban client to specifically check the status of the SSH jail.
fail2ban-client status sshd
echo ">>> Fail2ban installation and hardening complete."
sleep 2

# --- Step 4: Install Docker Engine and Docker Compose ---
echo ">>> STEP 4: Installing Docker Engine and Docker Compose..."
# Add Docker's official GPG key to verify package integrity.
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository to Apt sources.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Install the latest versions of Docker packages.
echo "Installing Docker packages..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add the current user (the one who ran sudo) to the docker group.
# This allows running docker commands without needing sudo every time.
# The SUDO_USER variable is set by the sudo command.
if [ -n "${SUDO_USER-}" ]; then
    echo "Adding user '$SUDO_USER' to the 'docker' group..."
    usermod -aG docker "$SUDO_USER"
    echo "NOTE: User '$SUDO_USER' must log out and log back in to run Docker without sudo."
fi

echo "Verifying Docker installation by running the 'hello-world' container..."
docker run hello-world
echo ">>> Docker installation complete."
sleep 2

# --- Step 5: Install Desktop Environment and X2Go Server ---
echo ">>> STEP 5: Installing XFCE Desktop and X2Go Server..."

# Install XFCE, a lightweight and stable desktop environment ideal for remote access.
echo "Installing XFCE desktop environment. This may take a few minutes..."
apt-get install -y xfce4 xfce4-goodies

# Install the X2Go Server, which provides the remote desktop protocol.
echo "Installing X2Go Server..."
apt-get install -y x2goserver x2goserver-xsession

echo ">>> XFCE and X2Go Server installation complete."
sleep 2

# --- Finalization ---
# Turn off command tracing for a cleaner final message.
set +x

echo "================================================================================"
echo "      SERVER SETUP COMPLETE! A REBOOT IS RECOMMENDED."
echo "================================================================================"
echo
echo "Summary of actions performed:"
echo " ✓ System packages updated and upgraded."
echo " ✓ UFW Firewall is active and allows incoming SSH (port 22)."
echo " ✓ Fail2ban is active and protecting SSH from brute-force attacks."
echo " ✓ Docker Engine and Compose are installed and verified."
echo " ✓ XFCE Desktop Environment is installed."
echo " ✓ X2Go Server is installed for remote desktop access."
echo
echo "--------------------------- IMPORTANT NEXT STEPS -----------------------------"
echo "1. Reboot the server to ensure all changes are applied correctly:"
echo "   sudo reboot"
echo
echo "2. To use Docker without sudo, the user '$SUDO_USER' must log out and log back in."
echo
echo "3. To connect via remote desktop:"
echo "   - On your local computer, download and install the 'X2Go Client'."
echo "   - Create a new session in the X2Go Client:"
echo "     - Host: Your server's IP address"
echo "     - Login: Your username"
echo "     - SSH port: 22"
echo "     - Use SSH key authentication for best security."
echo "     - Session type: Set this to 'XFCE'."
echo "================================================================================"

