#!/bin/bash
# Ubuntu Server Hardening Script
# This script implements basic security hardening measures:
# - Configures automatic security updates
# - Hardens SSH configuration (no root login, key authentication)
# - Configures UFW firewall with default deny
# - Changes SSH port to 23344

# Exit on error
set -e

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[*] Starting Ubuntu Server hardening process...${NC}"

read -p "Verify you have set up a ssh key. (enter to confirm) " -n 1 -r

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}[-] This script must be run as root${NC}"
  exit 1
fi

# Step 1: Install and configure automatic security updates
echo -e "${YELLOW}[*] Installing and configuring automatic updates...${NC}"
apt-get update
apt-get install -y unattended-upgrades

systemctl enable unattended-upgrades
systemctl restart unattended-upgrades
echo -e "${GREEN}[+] Automatic updates configured${NC}"

# Step 2: Harden SSH configuration (without restarting)
echo -e "${YELLOW}[*] Hardening SSH configuration...${NC}"

# Backup original SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Update SSH configuration
cat >/etc/ssh/sshd_config <<EOF
# SSH Server Configuration
Port 23344
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Authentication
LoginGraceTime 30
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 5

# Only use SSH key authentication
PasswordAuthentication no
# ChallengeResponseAuthentication no
# UsePAM yes

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Other restrictions
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
AllowTcpForwarding no
AllowAgentForwarding no
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 2
Banner /etc/issue.net
EOF

echo -e "${GREEN}[+] SSH hardened. Restarting ssh service...${NC}"
systemctl restart ssh

# Step 3: Configure UFW firewall with default deny
echo -e "${YELLOW}[*] Configuring UFW firewall...${NC}"
apt-get install -y ufw

# Reset UFW to default
ufw --force reset

# Set default policies
ufw default deny

# Allow SSH on custom port
ufw allow 23344/tcp

echo -e "${GREEN}[+] UFW configured with default deny policy${NC}"
echo -e "${GREEN}[+] Allowed incoming traffic on SSH port 23344${NC}"

echo -e "${GREEN}[+] Server hardening completed successfully!${NC}"
echo -e "${YELLOW}[*] Enable updated firewall using: ufw enable"
echo -e "${RED}[!] You will most likely need to reconnect."
