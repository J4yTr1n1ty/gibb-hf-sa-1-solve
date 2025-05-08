#!/bin/bash
# Security Hardening Verification Script
# This script verifies the security hardening measures implemented on the system:
# - Verifies automatic updates configuration
# - Checks SSH hardening configuration
# - Validates UFW firewall rules
# - Confirms SSH is running on the custom port

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[*] Starting security verification check...${NC}"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${YELLOW}[!] Warning: This script should be run as root for full verification${NC}"
fi

# Section header function
section() {
  echo -e "\n${BLUE}[*] $1${NC}"
  echo -e "${BLUE}===========================================${NC}"
}

# Result helper functions
pass() {
  echo -e "${GREEN}[+] $1${NC}"
}

fail() {
  echo -e "${RED}[-] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[!] $1${NC}"
}

info() {
  echo -e "[*] $1"
}

# 1. Verify Automatic Updates
section "Checking Automatic Updates Configuration"

if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
  if grep -q "APT::Periodic::Unattended-Upgrade \"1\";" /etc/apt/apt.conf.d/20auto-upgrades; then
    pass "Unattended upgrades are enabled"
  else
    fail "Unattended upgrades are not enabled"
  fi
else
  fail "Automatic updates configuration file not found"
fi

if systemctl is-active --quiet unattended-upgrades; then
  pass "Unattended-upgrades service is running"
else
  fail "Unattended-upgrades service is not running"
fi

# 2. Verify SSH Hardening
section "Checking SSH Configuration"

SSH_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSH_CONFIG" ]; then
  info "SSH configuration file exists"

  # Check SSH port
  SSH_PORT=$(grep -E "^Port" "$SSH_CONFIG" | awk '{print $2}')
  if [ "$SSH_PORT" = "23344" ]; then
    pass "SSH configured on custom port 23344"
  else
    fail "SSH not configured on the expected port (found: $SSH_PORT)"
  fi

  # Check root login
  ROOT_LOGIN=$(grep -E "^PermitRootLogin" "$SSH_CONFIG" | awk '{print $2}')
  if [ "$ROOT_LOGIN" = "no" ]; then
    pass "Root login is disabled"
  else
    fail "Root login is enabled or not explicitly disabled"
  fi

  # Check password authentication
  PASS_AUTH=$(grep -E "^PasswordAuthentication" "$SSH_CONFIG" | awk '{print $2}')
  if [ "$PASS_AUTH" = "no" ]; then
    pass "Password authentication is disabled (key-only authentication)"
  else
    warn "Password authentication is still enabled or not explicitly disabled"
    info "This is expected if you haven't set up SSH keys yet"
  fi

  # Check pubkey authentication
  PUBKEY_AUTH=$(grep -E "^PubkeyAuthentication" "$SSH_CONFIG" | awk '{print $2}')
  if [ "$PUBKEY_AUTH" = "yes" ]; then
    pass "Public key authentication is enabled"
  else
    fail "Public key authentication is disabled or not explicitly enabled"
  fi

  # Other SSH security settings
  grep -E "^X11Forwarding no" "$SSH_CONFIG" >/dev/null &&
    pass "X11 forwarding is disabled" ||
    fail "X11 forwarding is not disabled"

  grep -E "^PermitEmptyPasswords no" "$SSH_CONFIG" >/dev/null &&
    pass "Empty passwords are not permitted" ||
    fail "Empty passwords may be permitted"

  grep -E "^Protocol 2" "$SSH_CONFIG" >/dev/null &&
    pass "SSH Protocol 2 is enforced" ||
    warn "SSH Protocol 2 may not be explicitly enforced"
else
  fail "SSH configuration file not found"
fi

# Check if SSH service is running
if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
  pass "SSH service is running"
else
  fail "SSH service is not running"
fi

# 3. Verify UFW Configuration
section "Checking UFW Firewall Configuration"

if command -v ufw >/dev/null; then
  info "UFW is installed"

  if ufw status | grep -q "Status: active"; then
    pass "UFW firewall is active"

    # Check default policies
    if ufw status verbose | grep -q "Default: deny (incoming)"; then
      pass "UFW default deny incoming policy is set"
    else
      fail "UFW default deny incoming policy is not set"
    fi

    if ufw status verbose | grep -q "allow (outgoing)"; then
      pass "UFW default allow outgoing policy is set"
    else
      fail "UFW default allow outgoing policy is not set"
    fi

    # Check SSH port rule
    if ufw status | grep -q "23344/tcp.*ALLOW"; then
      pass "UFW allows traffic on SSH port 23344"
    else
      fail "UFW does not allow traffic on SSH port 23344"
    fi

    # Additional open ports (information only)
    OTHER_PORTS=$(ufw status | grep "ALLOW" | grep -v "23344/tcp" | awk '{print $1}')
    if [ -n "$OTHER_PORTS" ]; then
      warn "Other ports are also open:"
      ufw status | grep "ALLOW" | grep -v "23344/tcp"
    else
      pass "No additional ports are open"
    fi
  else
    fail "UFW firewall is not active"
  fi
else
  fail "UFW is not installed"
fi

# 4. Verify SSH is actually running on port 23344
section "Verifying SSH Service Port"

if command -v netstat >/dev/null || command -v ss >/dev/null; then
  if command -v netstat >/dev/null; then
    SSH_LISTENING=$(netstat -tuln | grep ":23344")
  else
    SSH_LISTENING=$(ss -tuln | grep ":23344")
  fi

  if [ -n "$SSH_LISTENING" ]; then
    pass "SSH service is listening on port 23344"
    info "$SSH_LISTENING"
  else
    fail "SSH service is not listening on port 23344"
    warn "SSH might still be on the default port or not running"

    if command -v netstat >/dev/null; then
      info "Current listening SSH ports:"
      netstat -tuln | grep "sshd" || echo "No SSH ports found"
    else
      info "Current listening SSH ports:"
      ss -tuln | grep "ssh" || echo "No SSH ports found"
    fi
  fi
else
  warn "Neither netstat nor ss commands are available to verify listening ports"
fi

# Summary
section "Security Verification Summary"
echo -e "The security verification check has been completed."
echo -e "Review any ${RED}[-] Failed${NC} or ${YELLOW}[!] Warning${NC} items above and take appropriate action."
echo -e "Remember that some warnings might be expected if you haven't completed all hardening steps."
