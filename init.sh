﻿#!/bin/bash

# Ubuntu Server Setup Script with Menu System
# Comprehensive installation, uninstallation, testing, and configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================================================"
    echo -e "$1"
    echo -e "================================================================================"
    echo -e "${NC}"
}

print_section() {
    echo -e "${CYAN}--- $1 ---${NC}"
}

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
       echo "running as root"
    fi
}

# Function to check sudo privileges
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo privileges. Please run with sudo access."
        exit 1
    fi
}

# Function to create admin user
create_admin_user() {
    print_header "Admin User Setup"
    
    # Get admin username
    read -p "Enter admin username: " admin_username
    if [[ -z "$admin_username" ]]; then
        print_error "Username cannot be empty"
        exit 1
    fi
    
    # Check if user already exists
    if id "$admin_username" &>/dev/null; then
        print_warning "User $admin_username already exists"
        read -p "Do you want to continue with existing user? (y/n): " continue_existing
        if [[ ! "$continue_existing" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        # Create new user
        print_status "Creating user $admin_username..."
        sudo adduser --gecos "" "$admin_username"
        sudo usermod -aG sudo "$admin_username"
        print_status "User $admin_username created and added to sudo group"
    fi
    
    # Get SSH public key
    print_section "SSH Key Setup"
    echo "Please provide your SSH public key (the content of your ~/.ssh/id_rsa.pub file)"
    echo "You can copy it from your local machine with: cat ~/.ssh/id_rsa.pub"
    echo "Paste the key below (press Enter twice when done):"
    
    # Create SSH directory for admin user
    sudo mkdir -p /home/"$admin_username"/.ssh
    sudo touch /home/"$admin_username"/.ssh/authorized_keys
    
    # Read SSH key
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            break
        fi
        echo "$line" | sudo tee -a /home/"$admin_username"/.ssh/authorized_keys > /dev/null
    done
    
    # Set proper permissions
    sudo chown -R "$admin_username:$admin_username" /home/"$admin_username"/.ssh
    sudo chmod 700 /home/"$admin_username"/.ssh
    sudo chmod 600 /home/"$admin_username"/.ssh/authorized_keys
    
    print_status "SSH key configured for user $admin_username"
    
    # Get root password
    print_section "Root Password Setup"
    echo "Set a password for root user (this will be used to switch from admin to root)"
    sudo passwd root
    
    # Configure SSH to disable password authentication and root login
    print_section "SSH Security Configuration"
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Update SSH configuration
    sudo tee -a /etc/ssh/sshd_config > /dev/null << EOF

# Security Configuration
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
EOF
    
    # Restart SSH service
    sudo systemctl restart ssh
    sudo systemctl enable ssh
    
    print_status "SSH configured for key authentication only"
    print_warning "Root login via SSH disabled"
    print_warning "Password authentication disabled"
    
    # Store admin username for later use
    echo "$admin_username" > /tmp/admin_username
}

# Function to setup GitHub repository
setup_github_repo() {
    print_section "GitHub Repository Setup"
    
    # Get GitHub repository URL
    read -p "Enter GitHub repository URL (e.g., https://github.com/username/repo.git): " github_repo_url
    if [[ -z "$github_repo_url" ]]; then
        print_error "GitHub repository URL cannot be empty"
        exit 1
    fi
    
    # Get admin username
    admin_username=$(cat /tmp/admin_username 2>/dev/null || echo "")
    if [[ -z "$admin_username" ]]; then
        read -p "Enter admin username: " admin_username
    fi
    
    # Create repository directory in admin user's home
    sudo mkdir -p /home/"$admin_username"/ubuntuX
    sudo chown "$admin_username:$admin_username" /home/"$admin_username"/ubuntuX
    
    # Clone repository as admin user
    sudo -u "$admin_username" git clone "$github_repo_url" /home/"$admin_username"/ubuntuX
    
    # Create refreshSetup command
    sudo tee /usr/local/bin/refreshSetup > /dev/null << EOF
#!/bin/bash
cd /home/$admin_username/ubuntuX
git pull origin main
chmod +x init.sh
dos2unix init.sh 2>/dev/null || true
echo "Repository updated successfully!"
echo "Run: ./init.sh to start the setup script"
EOF
    
    sudo chmod +x /usr/local/bin/refreshSetup
    
    # Create alias for admin user
    sudo -u "$admin_username" tee -a /home/"$admin_username"/.bashrc > /dev/null << EOF

# UbuntuX Setup Aliases
alias refreshSetup='cd /home/$admin_username/ubuntuX && git pull origin main && chmod +x init.sh && dos2unix init.sh 2>/dev/null || true && echo "Repository updated successfully!"'
alias setup='cd /home/$admin_username/ubuntuX && ./init.sh'
EOF
    
    print_status "GitHub repository setup completed"
    print_status "You can now use 'refreshSetup' command to update the repository"
    print_status "Repository location: /home/$admin_username/ubuntuX"
}

# Function to update system packages
update_system() {
    print_section "Updating System Packages"
    sudo apt update
    sudo apt upgrade -y
    print_status "System packages updated successfully"
}

# Function to install SSH key authentication
install_ssh() {
    print_section "Installing and Configuring SSH"
    
    # Install OpenSSH server
    sudo apt install -y openssh-server
    
    # Create SSH directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Generate SSH key if it doesn't exist
    if [[ ! -f ~/.ssh/id_rsa ]]; then
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        print_status "SSH key pair generated"
    fi
    
    # Configure SSH for key authentication
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    sudo tee -a /etc/ssh/sshd_config > /dev/null << EOF

# Custom SSH Configuration
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
EOF
    
    # Restart SSH service
    sudo systemctl restart ssh
    sudo systemctl enable ssh
    
    print_status "SSH configured for key authentication"
}

# Function to uninstall SSH
uninstall_ssh() {
    print_section "Uninstalling SSH"
    sudo apt remove -y openssh-server
    sudo apt autoremove -y
    print_status "SSH server removed"
}

# Function to install UFW firewall
install_ufw() {
    print_section "Installing and Configuring UFW Firewall"
    
    sudo apt install -y ufw
    
    # Configure UFW
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 5901/tcp  # VNC port 1
    sudo ufw allow 5902/tcp  # VNC port 2
    sudo ufw allow 5903/tcp  # VNC port 3
    sudo ufw --force enable
    
    print_status "UFW firewall configured and enabled"
}

# Function to uninstall UFW
uninstall_ufw() {
    print_section "Uninstalling UFW"
    sudo ufw --force disable
    sudo apt remove -y ufw
    sudo apt autoremove -y
    print_status "UFW firewall removed"
}

# Function to install fail2ban
install_fail2ban() {
    print_section "Installing and Configuring Fail2ban"
    
    sudo apt install -y fail2ban
    
    # Create fail2ban configuration
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban
    
    print_status "Fail2ban configured and enabled"
}

# Function to uninstall fail2ban
uninstall_fail2ban() {
    print_section "Uninstalling Fail2ban"
    sudo systemctl stop fail2ban
    sudo systemctl disable fail2ban
    sudo apt remove -y fail2ban
    sudo apt autoremove -y
    print_status "Fail2ban removed"
}

# Function to install Docker
install_docker() {
    print_section "Installing Docker and Docker Compose"
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    print_status "Docker and Docker Compose installed"
}

# Function to uninstall Docker
uninstall_docker() {
    print_section "Uninstalling Docker"
    sudo systemctl stop docker
    sudo systemctl disable docker
    sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    sudo apt autoremove -y
    sudo rm -rf /var/lib/docker
    sudo rm -rf /usr/local/bin/docker-compose
    print_status "Docker removed"
}

# Function to install Wayfire and VNC
install_wayfire_vnc() {
    print_section "Installing Wayfire Compositor and VNC Server"
    
    # Install Wayfire and dependencies
    sudo apt install -y wayfire wayfire-plugins-extra tigervnc-standalone-server tigervnc-common
    
    # Create Wayfire configuration directory
    mkdir -p ~/.config
    
    # Create basic Wayfire configuration
    cat > ~/.config/wayfire.ini << EOF
[core]
plugins = wm-actions,command,autostart

[wm-actions]
mod = <super>

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
    chmod 600 ~/.config/wayfire.ini
    
    print_status "Wayfire Compositor and VNC server installed"
}

# Function to uninstall Wayfire and VNC
uninstall_wayfire_vnc() {
    print_section "Uninstalling Wayfire and VNC"
    sudo apt remove -y wayfire wayfire-plugins-extra tigervnc-standalone-server tigervnc-common
    sudo apt autoremove -y
    rm -rf ~/.config/wayfire.ini
    rm -rf ~/.vnc
    print_status "Wayfire and VNC removed"
}

# Function to test all components
test_all() {
    print_section "Testing All Components"
    
    echo "Testing SSH..."
    if systemctl is-active --quiet ssh; then
        print_status "SSH service is running"
    else
        print_error "SSH service is not running"
    fi
    
    echo "Testing UFW..."
    if sudo ufw status | grep -q "Status: active"; then
        print_status "UFW firewall is active"
    else
        print_error "UFW firewall is not active"
    fi
    
    echo "Testing Fail2ban..."
    if systemctl is-active --quiet fail2ban; then
        print_status "Fail2ban service is running"
    else
        print_error "Fail2ban service is not running"
    fi
    
    echo "Testing Docker..."
    if systemctl is-active --quiet docker; then
        print_status "Docker service is running"
    else
        print_error "Docker service is not running"
    fi
    
    echo "Testing Wayfire..."
    if command -v wayfire >/dev/null 2>&1; then
        print_status "Wayfire is installed"
    else
        print_error "Wayfire is not installed"
    fi
    
    echo "Testing VNC..."
    if command -v vncserver >/dev/null 2>&1; then
        print_status "VNC server is installed"
    else
        print_error "VNC server is not installed"
    fi
}

# Function to test individual component
test_component() {
    local component=$1
    print_section "Testing $component"
    
    case $component in
        "ssh")
            if systemctl is-active --quiet ssh; then
                print_status "SSH service is running"
            else
                print_error "SSH service is not running"
            fi
            ;;
        "ufw")
            if sudo ufw status | grep -q "Status: active"; then
                print_status "UFW firewall is active"
            else
                print_error "UFW firewall is not active"
            fi
            ;;
        "fail2ban")
            if systemctl is-active --quiet fail2ban; then
                print_status "Fail2ban service is running"
            else
                print_error "Fail2ban service is not running"
            fi
            ;;
        "docker")
            if systemctl is-active --quiet docker; then
                print_status "Docker service is running"
            else
                print_error "Docker service is not running"
            fi
            ;;
        "wayfire")
            if command -v wayfire >/dev/null 2>&1; then
                print_status "Wayfire is installed"
            else
                print_error "Wayfire is not installed"
            fi
            ;;
        "vnc")
            if command -v vncserver >/dev/null 2>&1; then
                print_status "VNC server is installed"
            else
                print_error "VNC server is not installed"
            fi
            ;;
        *)
            print_error "Unknown component: $component"
            ;;
    esac
}

# Function to show configuration information
show_config_info() {
    print_header "Configuration Information"
    
    echo "System Information:"
    echo "=================="
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "User: $USER"
    echo ""
    
    echo "Network Information:"
    echo "==================="
    echo "IP Address: $(hostname -I | awk '{print $1}')"
    echo "SSH Port: 22"
    echo "VNC Ports: 5901, 5902, 5903"
    echo ""
    
    echo "Disk Space:"
    echo "==========="
    df -h /
    echo ""
    
    echo "Memory Usage:"
    echo "============="
    free -h
    echo ""
    
    echo "Service Status:"
    echo "==============="
    echo "SSH: $(systemctl is-active ssh 2>/dev/null || echo 'not installed')"
    echo "UFW: $(sudo ufw status | head -1 2>/dev/null || echo 'not installed')"
    echo "Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo 'not installed')"
    echo "Docker: $(systemctl is-active docker 2>/dev/null || echo 'not installed')"
    echo ""
    
    echo "Installed Components:"
    echo "===================="
    echo "Wayfire: $(command -v wayfire >/dev/null 2>&1 && echo 'installed' || echo 'not installed')"
    echo "VNC Server: $(command -v vncserver >/dev/null 2>&1 && echo 'installed' || echo 'not installed')"
    echo "Docker: $(command -v docker >/dev/null 2>&1 && echo 'installed' || echo 'not installed')"
    echo "Docker Compose: $(command -v docker-compose >/dev/null 2>&1 && echo 'installed' || echo 'not installed')"
    echo ""
    
    echo "Wayfire Configuration:"
    echo "====================="
    if [[ -f ~/.config/wayfire.ini ]]; then
        echo "Config file: ~/.config/wayfire.ini"
        echo "VNC startup script: ~/.vnc/xstartup"
    else
        echo "Wayfire not configured"
    fi
    echo ""
    
    echo "SSH Configuration:"
    echo "=================="
    if [[ -f ~/.ssh/id_rsa ]]; then
        echo "SSH key exists: ~/.ssh/id_rsa"
        echo "SSH key fingerprint: $(ssh-keygen -lf ~/.ssh/id_rsa | awk '{print $2}')"
    else
        echo "SSH key not found"
    fi
    echo ""
    
    echo "Firewall Rules:"
    echo "==============="
    sudo ufw status numbered 2>/dev/null || echo "UFW not installed or not active"
    echo ""
    
    echo "Docker Information:"
    echo "=================="
    if command -v docker >/dev/null 2>&1; then
        echo "Docker version: $(docker --version)"
        echo "Docker Compose version: $(docker-compose --version 2>/dev/null || echo 'not available')"
        echo "Docker images: $(docker images -q | wc -l) images"
        echo "Docker containers: $(docker ps -q | wc -l) running"
    else
        echo "Docker not installed"
    fi
    
    # Show admin user information
    if [[ -f /tmp/admin_username ]]; then
        admin_username=$(cat /tmp/admin_username)
        echo ""
        echo "Admin User Information:"
        echo "======================"
        echo "Admin Username: $admin_username"
        echo "Admin Home: /home/$admin_username"
        echo "Repository: /home/$admin_username/ubuntuX"
        echo "Refresh Command: refreshSetup"
    fi
}

# Function to show main menu
show_menu() {
    clear
    print_header "Ubuntu Server Setup Script"
    echo "Choose an option:"
    echo ""
    echo "1. Initial Server Setup (Admin User + GitHub)"
    echo "2. Install All Components (Automated)"
    echo "3. Install Individual Components"
    echo "4. Uninstall Components"
    echo "5. Test Components"
    echo "6. Show Configuration Information"
    echo "7. Exit"
    echo ""
}

# Function to show installation menu
show_install_menu() {
    clear
    print_header "Install Individual Components"
    echo "Choose components to install:"
    echo ""
    echo "1. SSH Key Authentication"
    echo "2. UFW Firewall"
    echo "3. Fail2ban"
    echo "4. Docker & Docker Compose"
    echo "5. Wayfire & VNC Server"
    echo "6. Back to Main Menu"
    echo ""
}

# Function to show uninstall menu
show_uninstall_menu() {
    clear
    print_header "Uninstall Components"
    echo "Choose components to uninstall:"
    echo ""
    echo "1. SSH"
    echo "2. UFW Firewall"
    echo "3. Fail2ban"
    echo "4. Docker"
    echo "5. Wayfire & VNC"
    echo "6. Back to Main Menu"
    echo ""
}

# Function to show test menu
show_test_menu() {
    clear
    print_header "Test Components"
    echo "Choose testing option:"
    echo ""
    echo "1. Test All Components"
    echo "2. Test Individual Components"
    echo "3. Back to Main Menu"
    echo ""
}

# Function to show individual test menu
show_individual_test_menu() {
    clear
    print_header "Test Individual Components"
    echo "Choose component to test:"
    echo ""
    echo "1. SSH"
    echo "2. UFW Firewall"
    echo "3. Fail2ban"
    echo "4. Docker"
    echo "5. Wayfire"
    echo "6. VNC Server"
    echo "7. Back to Test Menu"
    echo ""
}

# Main script execution
main() {
    check_root
    check_sudo
    
    while true; do
        show_menu
        read -p "Enter your choice (1-7): " choice
        
        case $choice in
            1)
                print_header "Initial Server Setup"
                create_admin_user
                setup_github_repo
                print_header "Initial Setup Complete!"
                print_status "Admin user created and GitHub repository configured"
                print_status "You can now log in as the admin user and use 'refreshSetup' command"
                wait_for_user
                ;;
            2)
                print_header "Installing All Components"
                update_system
                install_ssh
                install_ufw
                install_fail2ban
                install_docker
                install_wayfire_vnc
                print_header "All Components Installed Successfully!"
                print_status "A reboot is recommended to ensure all changes are applied correctly."
                wait_for_user
                ;;
            3)
                while true; do
                    show_install_menu
                    read -p "Enter your choice (1-6): " install_choice
                    
                    case $install_choice in
                        1) install_ssh; wait_for_user ;;
                        2) install_ufw; wait_for_user ;;
                        3) install_fail2ban; wait_for_user ;;
                        4) install_docker; wait_for_user ;;
                        5) install_wayfire_vnc; wait_for_user ;;
                        6) break ;;
                        *) print_error "Invalid choice"; wait_for_user ;;
                    esac
                done
                ;;
            4)
                while true; do
                    show_uninstall_menu
                    read -p "Enter your choice (1-6): " uninstall_choice
                    
                    case $uninstall_choice in
                        1) uninstall_ssh; wait_for_user ;;
                        2) uninstall_ufw; wait_for_user ;;
                        3) uninstall_fail2ban; wait_for_user ;;
                        4) uninstall_docker; wait_for_user ;;
                        5) uninstall_wayfire_vnc; wait_for_user ;;
                        6) break ;;
                        *) print_error "Invalid choice"; wait_for_user ;;
                    esac
                done
                ;;
            5)
                while true; do
                    show_test_menu
                    read -p "Enter your choice (1-3): " test_choice
                    
                    case $test_choice in
                        1) test_all; wait_for_user ;;
                        2)
                            while true; do
                                show_individual_test_menu
                                read -p "Enter your choice (1-7): " individual_test_choice
                                
                                case $individual_test_choice in
                                    1) test_component "ssh"; wait_for_user ;;
                                    2) test_component "ufw"; wait_for_user ;;
                                    3) test_component "fail2ban"; wait_for_user ;;
                                    4) test_component "docker"; wait_for_user ;;
                                    5) test_component "wayfire"; wait_for_user ;;
                                    6) test_component "vnc"; wait_for_user ;;
                                    7) break ;;
                                    *) print_error "Invalid choice"; wait_for_user ;;
                                esac
                            done
                            ;;
                        3) break ;;
                        *) print_error "Invalid choice"; wait_for_user ;;
                    esac
                done
                ;;
            6)
                show_config_info
                wait_for_user
                ;;
            7)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                wait_for_user
                ;;
        esac
    done
}

# Run main function
main
