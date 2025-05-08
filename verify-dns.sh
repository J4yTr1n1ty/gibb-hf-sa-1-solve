#!/bin/bash
# DNS Configuration Verification Script
# This script verifies the DNS configuration for smartlearn.lan and smartlearn.dmz zones

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[*] Starting DNS configuration verification...${NC}"

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

# 1. Verify BIND installation
section "Checking BIND9 Installation"

if command -v named &>/dev/null; then
  pass "BIND9 is installed"
  BIND_VERSION=$(named -v)
  info "BIND version: $BIND_VERSION"
else
  fail "BIND9 is not installed"
  exit 1
fi

# 2. Verify BIND service status
section "Checking BIND9 Service Status"

if systemctl is-active --quiet bind9; then
  pass "BIND9 service is running"
else
  fail "BIND9 service is not running"
  info "Attempting to show error logs:"
  journalctl -u bind9 --no-pager --lines=10
fi

if systemctl is-enabled --quiet bind9; then
  pass "BIND9 service is enabled to start on boot"
else
  warn "BIND9 service is not enabled to start on boot"
fi

# 3. Verify configuration files
section "Checking Configuration Files"

if [ -f /etc/bind/named.conf.local ]; then
  pass "named.conf.local exists"

  if grep -q "zone \"smartlearn.lan\"" /etc/bind/named.conf.local; then
    pass "smartlearn.lan zone is configured in named.conf.local"
  else
    fail "smartlearn.lan zone is not configured in named.conf.local"
  fi

  if grep -q "zone \"smartlearn.dmz\"" /etc/bind/named.conf.local; then
    pass "smartlearn.dmz zone is configured in named.conf.local"
  else
    fail "smartlearn.dmz zone is not configured in named.conf.local"
  fi

  if grep -q "zone \"110.168.192.in-addr.arpa\"" /etc/bind/named.conf.local; then
    pass "Reverse zone for 192.168.110.0/24 is configured"
  else
    fail "Reverse zone for 192.168.110.0/24 is not configured"
  fi

  if grep -q "zone \"120.168.192.in-addr.arpa\"" /etc/bind/named.conf.local; then
    pass "Reverse zone for 192.168.120.0/24 is configured"
  else
    fail "Reverse zone for 192.168.120.0/24 is not configured"
  fi
else
  fail "named.conf.local not found"
fi

# 4. Verify zone files
section "Checking Zone Files"

ZONE_FILES=(
  "/etc/bind/zones/db.smartlearn.lan"
  "/etc/bind/zones/db.smartlearn.dmz"
  "/etc/bind/zones/db.110.168.192"
  "/etc/bind/zones/db.120.168.192"
)

for file in "${ZONE_FILES[@]}"; do
  if [ -f "$file" ]; then
    pass "Zone file $file exists"

    # Check zone file syntax with named-checkzone
    ZONE_NAME=$(basename "$file" | sed 's/^db\.//')
    if [[ "$ZONE_NAME" == "110.168.192" ]]; then
      ZONE_NAME="110.168.192.in-addr.arpa"
    elif [[ "$ZONE_NAME" == "120.168.192" ]]; then
      ZONE_NAME="120.168.192.in-addr.arpa"
    fi

    CHECK_RESULT=$(named-checkzone "$ZONE_NAME" "$file" 2>&1)
    if echo "$CHECK_RESULT" | grep -q "OK"; then
      pass "Zone file $file syntax is valid"
    else
      fail "Zone file $file has syntax errors"
      info "$CHECK_RESULT"
    fi
  else
    fail "Zone file $file not found"
  fi
done

# 5. Verify DNS resolution for each host
section "Testing DNS Resolution"

# Function to test DNS resolution
test_dns_resolution() {
  local hostname=$1
  local expected_ip=$2
  local dns_server=${3:-127.0.0.1}

  result=$(nslookup "$hostname" "$dns_server" 2>/dev/null)
  resolved_ip=$(echo "$result" | grep -A1 "Name:" | grep "Address:" | awk '{print $2}')

  if [ "$resolved_ip" = "$expected_ip" ]; then
    pass "$hostname resolves to $resolved_ip (correct)"
  else
    if [ -z "$resolved_ip" ]; then
      fail "$hostname does not resolve"
    else
      fail "$hostname resolves to $resolved_ip (expected $expected_ip)"
    fi
  fi
}

# Test each hostname from the table
echo -e "${YELLOW}[!] Using the local DNS server for resolution tests${NC}"

# smartlearn.lan hosts
test_dns_resolution "vmkl1.smartlearn.lan" "192.168.110.70"
test_dns_resolution "vmlf1.smartlearn.lan" "192.168.110.1"

# smartlearn.dmz hosts
test_dns_resolution "vmlm1.smartlearn.dmz" "192.168.120.60"
test_dns_resolution "www.smartlearn.dmz" "192.168.120.60"
test_dns_resolution "dns.smartlearn.dmz" "192.168.120.60"
test_dns_resolution "vmlf1.smartlearn.dmz" "192.168.120.1"

# 6. Test reverse DNS
section "Testing Reverse DNS Resolution"

# Function to test reverse DNS
test_reverse_dns() {
  local ip=$1
  local expected_hostname=$2
  local dns_server=${3:-127.0.0.1}

  result=$(nslookup "$ip" "$dns_server" 2>/dev/null)
  resolved_name=$(echo "$result" | grep "name =" | awk '{print $4}' | sed 's/\.$//')

  if [ "$resolved_name" = "$expected_hostname" ]; then
    pass "Reverse lookup for $ip returns $resolved_name (correct)"
  else
    if [ -z "$resolved_name" ]; then
      fail "Reverse lookup for $ip does not resolve"
    else
      fail "Reverse lookup for $ip returns $resolved_name (expected $expected_hostname)"
    fi
  fi
}

# Test reverse DNS for each IP
test_reverse_dns "192.168.110.70" "vmkl1.smartlearn.lan"
test_reverse_dns "192.168.110.1" "vmlf1.smartlearn.lan"
test_reverse_dns "192.168.120.60" "vmlm1.smartlearn.dmz dns.smartlearn.dmz www.smartlearn.dmz" # Note: This has multiple PTRs, so might return any of them
test_reverse_dns "192.168.120.1" "vmlf1.smartlearn.dmz"

# 7. Check if DNS server is listening on the correct interfaces
section "Checking DNS Server Listening Status"

if command -v netstat &>/dev/null; then
  DNS_LISTEN=$(netstat -tuln | grep ":53")
  if [ -n "$DNS_LISTEN" ]; then
    pass "DNS server is listening on port 53"
    info "$DNS_LISTEN"
  else
    fail "DNS server is not listening on port 53"
  fi
elif command -v ss &>/dev/null; then
  DNS_LISTEN=$(ss -tuln | grep ":53")
  if [ -n "$DNS_LISTEN" ]; then
    pass "DNS server is listening on port 53"
    info "$DNS_LISTEN"
  else
    fail "DNS server is not listening on port 53"
  fi
else
  warn "Neither netstat nor ss commands are available to verify listening ports"
fi

# Summary
section "DNS Configuration Verification Summary"
echo -e "The DNS verification check has been completed."
echo -e "Review any ${RED}[-] Failed${NC} or ${YELLOW}[!] Warning${NC} items above and take appropriate action."
echo -e "\nExpected configuration based on the provided table:"
echo -e "--------------------------------------------------------"
echo -e "| Hostname | IP Address     | Domain          |"
echo -e "--------------------------------------------------------"
echo -e "| vmkl1    | 192.168.110.70 | smartlearn.lan  |"
echo -e "| vmlm1    | 192.168.120.60 | smartlearn.dmz  |"
echo -e "| www      | 192.168.120.60 | smartlearn.dmz  |"
echo -e "| dns      | 192.168.120.60 | smartlearn.dmz  |"
echo -e "| vmlf1    | 192.168.110.1  | smartlearn.lan  |"
echo -e "| vmlf1    | 192.168.120.1  | smartlearn.dmz  |"
echo -e "--------------------------------------------------------"
