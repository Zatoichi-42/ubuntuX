# Ubuntu Server Setup

A comprehensive setup script for configuring a brand new Ubuntu server with SSH key authentication, graphical interface, Docker, X2Go, and security hardening.

## 🚀 Features

- **SSH Key Authentication**: Secure SSH access with key-based authentication
- **Security Hardening**: fail2ban protection against brute force attacks
- **Graphical Interface**: XFCE4 lightweight desktop environment
- **Remote Access**: X2Go and VNC server support
- **Container Support**: Docker installation and configuration
- **Firewall**: UFW firewall with proper port configuration
- **System Updates**: Comprehensive system upgrade process
- **Test Cases**: Built-in verification tests

## 📋 Prerequisites

- Fresh Ubuntu system (tested on Ubuntu 20.04 LTS and later)
- Internet connection for package downloads
- Root or sudo privileges
- At least 2GB RAM (4GB recommended)
- 10GB free disk space

## 🛠️ Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/ubuntu-server-setup.git
   cd ubuntu-server-setup
   ```

2. **Make the script executable**:
   ```bash
   chmod +x ubuntu_server_setup.sh
   ```

3. **Run the setup script**:
   ```bash
   sudo ./ubuntu_server_setup.sh
   ```

## 📖 What the Script Does

### 🔐 Security Features
- **SSH Hardening**: Disables root login, password authentication, and configures key-based auth
- **fail2ban**: Protects against SSH brute force attacks
- **UFW Firewall**: Configures firewall with proper port rules
- **Security Banner**: Adds warning banner for SSH connections

### 🖥️ Desktop Environment
- **XFCE4**: Lightweight and fast desktop environment
- **LightDM**: Display manager configuration
- **Essential Apps**: Firefox, terminal, file manager

### 🌐 Remote Access
- **X2Go**: Secure remote desktop via SSH
- **VNC Server**: Additional remote desktop option
- **SSH Tunneling**: X11 forwarding support

### 🐳 Container Support
- **Docker**: Latest Docker CE installation
- **Docker Compose**: Container orchestration
- **User Permissions**: Adds user to docker group

### 📦 System Packages
- **Development Tools**: build-essential, python3, git
- **System Utilities**: htop, curl, wget, nmap
- **Monitoring**: iotop, nethogs (optional)

## 🔧 Configuration Options

The script includes maximum prompts for customization:

- **SSH Port**: Choose custom SSH port (default: 22)
- **Desktop Environment**: XFCE4, GNOME, KDE, or LXDE
- **SSH Key Type**: RSA or Ed25519
- **Firewall Rules**: Customize port access
- **Package Selection**: Choose which additional packages to install

## 🧪 Testing

After setup, run the built-in test cases:

```bash
./server_test_cases.sh
```

Tests include:
- SSH service status
- Firewall configuration
- Docker functionality
- X2Go service
- System resources
- Network connectivity

## 🔗 Connection Methods

### SSH Connection
```bash
ssh -i ~/.ssh/id_ed25519 username@server-ip
```

### X2Go Connection
- Use X2Go client
- Host: server-ip
- Login: username
- Session type: XFCE

### VNC Connection
```bash
# Start VNC server
vncserver -geometry 1920x1080 -depth 24

# Connect with VNC client
vncviewer server-ip:5901
```

## 📁 File Structure

```
ubuntu-server-setup/
├── ubuntu_server_setup.sh      # Main setup script
├── server_test_cases.sh        # Test cases
├── setup_complete.sh          # Completion summary
├── README.md                  # This file
├── LICENSE                    # MIT License
├── .gitignore                # Git ignore rules
├── CONTRIBUTING.md           # Contribution guidelines
└── CHANGELOG.md              # Version history
```

## 🛡️ Security Considerations

1. **Change Default Passwords**: Set strong passwords for all services
2. **Regular Updates**: Keep the system updated
3. **Monitor Logs**: Check for suspicious activity
4. **VPN Access**: Consider VPN for additional security
5. **Backup Keys**: Secure backup of SSH keys
6. **Firewall Rules**: Review and customize as needed

## 🔍 Troubleshooting

### SSH Issues
```bash
# Check SSH service
sudo systemctl status ssh

# View SSH logs
sudo journalctl -u ssh

# Test SSH config
sudo sshd -t
```

### Docker Issues
```bash
# Check Docker service
sudo systemctl status docker

# Test Docker
sudo docker run hello-world

# Check user permissions
groups $USER
```

### X2Go Issues
```bash
# Check X2Go service
sudo systemctl status x2goserver

# View X2Go logs
sudo journalctl -u x2goserver
```

### Firewall Issues
```bash
# Check firewall status
sudo ufw status verbose

# Allow additional ports
sudo ufw allow 8080/tcp
```

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Ubuntu community for excellent documentation
- XFCE team for lightweight desktop environment
- Docker team for container technology
- X2Go team for remote desktop solution

## 📞 Support

If you encounter any issues:

1. Check the troubleshooting section
2. Review system logs
3. Run the test cases
4. Open an issue on GitHub

## 🔄 Version History

See [CHANGELOG.md](CHANGELOG.md) for a complete version history.

---

**Note**: This script is designed for educational and personal use. Use in production environments at your own risk. 