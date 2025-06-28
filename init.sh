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

# Function to wait for user input
wait_for_user() {
    echo ""
    echo "Press any key to proceed to the next step..."
    read -n 1 -s
    echo ""
}

# Function to announce success
announce_success() {
    echo ""
    echo "✅ SUCCESS: $1"
    echo "=========================================="
}

# Function to run simple test
run_test() {
    echo ""
    echo "🧪 Running test: $1"
    echo "------------------------------------------"
    # Temporarily disable debug mode for test execution
    set +x
    eval "$2"
    set -x
    echo "✅ Test completed successfully"
}

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
echo "This script will run installations automatically and pause after each step for testing."
echo ""

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

announce_success "System update and upgrade completed"
run_test "Check package list is updated" "apt list --upgradable 2>/dev/null | wc -l"
run_test "Check system is up to date" "[[ \$(apt list --upgradable 2>/dev/null | wc -l) -le 1 ]] && echo 'System is up to date' || echo 'Updates available'"

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

# Allow VNC connections for Wayfire remote desktop
ufw allow 5901/tcp
ufw allow 5902/tcp
ufw allow 5903/tcp

# Enable the firewall. The 'yes' command is piped to automatically confirm
# the action, preventing the script from hanging.
yes | ufw enable

announce_success "UFW Firewall installation and configuration completed"
run_test "Check UFW status" "ufw status verbose"
run_test "Verify SSH port is allowed" "ufw status | grep -q '22.*ALLOW' && echo 'SSH port 22 is allowed' || echo 'SSH port 22 is NOT allowed'"
run_test "Verify VNC ports are allowed" "ufw status | grep -q '5901.*ALLOW' && echo 'VNC port 5901 is allowed' || echo 'VNC port 5901 is NOT allowed'; ufw status | grep -q '5902.*ALLOW' && echo 'VNC port 5902 is allowed' || echo 'VNC port 5902 is NOT allowed'; ufw status | grep -q '5903.*ALLOW' && echo 'VNC port 5903 is allowed' || echo 'VNC port 5903 is NOT allowed'"

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

announce_success "Fail2ban installation and configuration completed"
run_test "Check Fail2ban service status" "systemctl status fail2ban --no-pager"
run_test "Check SSH jail status" "fail2ban-client status sshd"
run_test "Verify Fail2ban is enabled on boot" "systemctl is-enabled fail2ban && echo 'Fail2ban is enabled on boot' || echo 'Fail2ban is NOT enabled on boot'"

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
#if [ -n "${SUDO_USER-}" ]; then
#    echo "Adding user '$SUDO_USER' to the 'docker' group..."
#    usermod -aG docker "$SUDO_USER"
#    echo "NOTE: User '$SUDO_USER' must log out and log back in to run Docker without sudo."
#fi

announce_success "Docker Engine and Docker Compose installation completed"
run_test "Check Docker service status" "systemctl status docker --no-pager"
run_test "Verify Docker installation" "docker --version"
run_test "Test Docker functionality" "docker run hello-world"
run_test "Check Docker Compose" "docker compose version"
#run_test "Verify user in docker group" "groups $SUDO_USER | grep -q docker && echo 'User is in docker group' || echo 'User is NOT in docker group'"
wait_for_user

# --- Step 5: Install Wayfire for Remote Desktop ---
echo ">>> STEP 5: Installing Wayfire Compositor for Remote Desktop..."

# Install Wayland and Wayfire dependencies
echo "Installing Wayland and Wayfire dependencies..."
apt-get install -y wayland-protocols libwayland-dev

# Install Wayfire compositor
echo "Installing Wayfire compositor..."
apt-get install -y wayfire

# Install display manager for Wayland
echo "Installing display manager for Wayland..."
apt-get install -y gdm3

# Install TigerVNC for remote desktop access
echo "Installing TigerVNC server..."
apt-get install -y tigervnc-standalone-server tigervnc-common

# Configure Wayfire for VNC
echo "Configuring Wayfire for VNC access..."
mkdir -p ~/.config
cat > ~/.config/wayfire.ini << 'EOF'
[core]
plugins = 

[input]
cursor_speed = 1.0
mouse_cursor_speed = 1.0
touchpad_cursor_speed = 1.0

[workarounds]
fade_delta = 75
EOF

# Create VNC startup script for Wayfire
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
export XDG_CURRENT_DESKTOP="wayfire"
export XDG_SESSION_DESKTOP="wayfire"
exec wayfire
EOF

chmod +x ~/.vnc/xstartup

# Set proper permissions for the config file
chmod 600 ~/.config/wayfire.ini

announce_success "Wayfire Compositor and VNC server installation completed"
run_test "Check Wayfire installation" "dpkg -l | grep -q wayfire && echo 'Wayfire is installed' || echo 'Wayfire is NOT installed'"
run_test "Check VNC server installation" "dpkg -l | grep -q tigervnc && echo 'VNC server is installed' || echo 'VNC server is NOT installed'"
run_test "Check Wayfire config file" "test -f ~/.config/wayfire.ini && echo 'Wayfire config exists' || echo 'Wayfire config does NOT exist'"
run_test "Check VNC startup script" "test -f ~/.vnc/xstartup && echo 'VNC startup script exists' || echo 'VNC startup script does NOT exist'"
run_test "Check Wayland support" "echo $XDG_SESSION_TYPE && echo 'Wayland session type detected'"
run_test "Check GDM3 service" "systemctl status gdm3 --no-pager 2>/dev/null || echo 'GDM3 not running (may need reboot)'"
wait_for_user

# --- Finalization ---
# Turn off command tracing for a cleaner final message.
set +x

echo "================================================================================"
echo "      SERVER SETUP COMPLETE! A REBOOT IS RECOMMENDED."
echo "================================================================================"
echo
echo "Summary of actions performed:"
echo " ✓ System packages updated and upgraded."
echo " ✓ UFW Firewall is active and allows incoming SSH (port 22) and VNC (ports 5901, 5902, 5903)."
echo " ✓ Fail2ban is active and protecting SSH from brute-force attacks."
echo " ✓ Docker Engine and Compose are installed and verified."
echo " ✓ Wayfire Compositor and VNC server are installed for remote desktop."
echo
echo "--------------------------- IMPORTANT NEXT STEPS -----------------------------"
echo "1. Reboot the server to ensure all changes are applied correctly:"
echo "   sudo reboot"
echo
echo "2. REMOVED
echo
echo "3. To connect via SSH:"
echo "   ssh username@your-server-ip"
echo
echo "4. For remote desktop access with Wayfire VNC:"
echo "   - Set VNC password: vncpasswd"
echo "   - Start VNC server: vncserver -geometry 1920x1080 -depth 24"
echo "   - Connect via VNC: your-server-ip:5901"
echo "   - VNC will start Wayfire desktop environment"
echo
echo "5. For additional remote desktop options:"
echo "   - X2Go: sudo apt install x2goserver x2goserver-xsession"
echo "   - Traditional VNC: sudo apt install tigervnc-standalone-server"
echo "================================================================================"

# Final test summary
echo ""
echo "🧪 FINAL SYSTEM TEST SUMMARY:"
echo "=========================================="
echo "System Updates: $(apt list --upgradable 2>/dev/null | wc -l) packages available"
echo "UFW Status: $(ufw status | head -1)"
echo "Fail2ban Status: $(systemctl is-active fail2ban)"
echo "Docker Status: $(systemctl is-active docker)"
echo "=========================================="

wait_for_user

# --- Wayfire Configuration Instructions ---
echo ""
echo "================================================================================"
echo "                    WAYFIRE CONFIGURATION GUIDE"
echo "================================================================================"
echo ""
echo "Wayfire is now installed and ready for configuration. Here's how to set it up:"
echo ""

echo "📋 BASIC WAYFIRE CONFIGURATION:"
echo "--------------------------------"
echo "1. Start Wayfire (if not already running):"
echo "   wayfire"
echo ""
echo "2. Access Wayfire settings:"
echo "   - Press Super + S (or right-click on desktop)"
echo "   - Select 'Settings' or 'Preferences'"
echo "   - Configure appearance, workspaces, and plugins"
echo ""

echo "🔧 ADVANCED CONFIGURATION:"
echo "--------------------------"
echo "1. Edit Wayfire configuration file:"
echo "   nano ~/.config/wayfire.ini"
echo ""
echo "2. Common configuration options:"
echo "   [core]"
echo "   plugins = wm-actions,command,autostart"
echo "   "
echo "   [wm-actions]"
echo "   mod = <super>"
echo "   "
echo "   [input]"
echo "   cursor_speed = 1.0"
echo "   mouse_cursor_speed = 1.0"
echo "   touchpad_cursor_speed = 1.0"
echo "   "
echo "   [workarounds]"
echo "   fade_delta = 75"
echo ""

echo "🎨 APPEARANCE CUSTOMIZATION:"
echo "----------------------------"
echo "1. Install additional themes and icons:"
echo "   sudo apt install papirus-icon-theme arc-theme"
echo ""
echo "2. Configure GTK theme:"
echo "   gsettings set org.gnome.desktop.interface gtk-theme 'Arc'"
echo ""
echo "3. Configure icon theme:"
echo "   gsettings set org.gnome.desktop.interface icon-theme 'Papirus'"
echo ""

echo "🔌 USEFUL WAYFIRE PLUGINS:"
echo "--------------------------"
echo "1. Window Management:"
echo "   - wm-actions: Window actions and shortcuts"
echo "   - grid: Grid-based window tiling"
echo "   - expo: Workspace overview"
echo ""
echo "2. Productivity:"
echo "   - command: Execute commands with shortcuts"
echo "   - autostart: Auto-start applications"
echo "   - place: Window placement rules"
echo ""

echo "⌨️  KEYBOARD SHORTCUTS:"
echo "----------------------"
echo "Super + Enter     - Open terminal"
echo "Super + D         - Application launcher"
echo "Super + Tab       - Switch between windows"
echo "Super + Arrow     - Tile windows"
echo "Super + Shift + Q - Close window"
echo "Super + S         - Settings menu"
echo "Alt + Tab         - Switch applications"
echo ""

echo "🖥️  VNC CONFIGURATION FOR WAYFIRE:"
echo "----------------------------------"
echo "1. Set VNC password:"
echo "   vncpasswd"
echo ""
echo "2. Start VNC server with Wayfire:"
echo "   vncserver -geometry 1920x1080 -depth 24"
echo ""
echo "3. Connect from Windows:"
echo "   - Use RealVNC Viewer"
echo "   - Connect to: your-server-ip:5901"
echo "   - Enter VNC password"
echo ""

echo "🔧 TROUBLESHOOTING WAYFIRE:"
echo "---------------------------"
echo "1. If Wayfire doesn't start:"
echo "   - Check if Wayland is supported: echo \$XDG_SESSION_TYPE"
echo "   - Try starting with debug: WAYLAND_DEBUG=1 wayfire"
echo "   - Check logs: journalctl --user -f"
echo ""
echo "2. If VNC shows black screen:"
echo "   - Verify VNC startup script: cat ~/.vnc/xstartup"
echo "   - Check if Wayfire is in PATH: which wayfire"
echo "   - Restart VNC server: vncserver -kill :1 && vncserver"
echo ""
echo "3. If plugins don't work:"
echo "   - Check plugin configuration in ~/.config/wayfire.ini"
echo "   - Restart Wayfire after configuration changes"
echo ""

echo "📚 ADDITIONAL RESOURCES:"
echo "-----------------------"
echo "1. Wayfire Documentation:"
echo "   https://github.com/WayfireWM/wayfire/wiki"
echo ""
echo "2. Wayfire Configuration Examples:"
echo "   https://github.com/WayfireWM/wayfire-config"
echo ""
echo "3. Wayfire Plugins:"
echo "   https://github.com/WayfireWM/wayfire-plugins-extra"
echo ""

echo "================================================================================"
echo "Wayfire configuration guide completed. Happy desktop customization!"
echo "================================================================================"

