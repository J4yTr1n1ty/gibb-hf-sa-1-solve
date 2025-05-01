#!/bin/bash
# DNS Setup Script for smartlearn.lan and smartlearn.dmz Zones
# This script installs and configures BIND9 DNS server with two zones

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[*] Starting DNS server installation and configuration...${NC}"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}[-] This script must be run as root${NC}"
  exit 1
fi

# Install BIND9 DNS server
echo -e "${YELLOW}[*] Installing BIND9 DNS server...${NC}"
apt-get update
apt-get install -y bind9 bind9utils bind9-doc

# Backup original configuration
echo -e "${YELLOW}[*] Backing up original configuration...${NC}"
cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak
cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bak

# Configure BIND options
echo -e "${YELLOW}[*] Configuring BIND options...${NC}"
cat >/etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    // Listen on local interfaces only
    listen-on { 127.0.0.1; 192.168.110.60; 192.168.120.60; };
    listen-on-v6 { ::1; };

    // Allow queries from local networks only
    allow-query {
        localhost;
        192.168.110.0/24;
        192.168.120.0/24;
    };

    // Disable recursive queries for security
    recursion yes;
    allow-recursion {
        localhost;
        192.168.110.0/24;
        192.168.120.0/24;
    };

    // Forward DNS queries if this server doesn't have the answer
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    // Security settings
    auth-nxdomain no;
    version none;
    dnssec-validation auto;
};
EOF

# Configure zones
echo -e "${YELLOW}[*] Configuring local zones...${NC}"
cat >/etc/bind/named.conf.local <<EOF
// Local zones for smartlearn.lan and smartlearn.dmz

// Zone for smartlearn.lan
zone "smartlearn.lan" {
    type master;
    file "/etc/bind/zones/db.smartlearn.lan";
    allow-transfer { none; };
};

// Zone for smartlearn.dmz
zone "smartlearn.dmz" {
    type master;
    file "/etc/bind/zones/db.smartlearn.dmz";
    allow-transfer { none; };
};

// Reverse zones
zone "110.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.110.168.192";
    allow-transfer { none; };
};

zone "120.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.120.168.192";
    allow-transfer { none; };
};
EOF

# Create zones directory
echo -e "${YELLOW}[*] Creating zones directory...${NC}"
mkdir -p /etc/bind/zones

# Create zone file for smartlearn.lan
echo -e "${YELLOW}[*] Creating zone file for smartlearn.lan...${NC}"
cat >/etc/bind/zones/db.smartlearn.lan <<EOF
\$TTL    86400
@       IN      SOA     vmkl1.smartlearn.lan. admin.smartlearn.lan. (
                  2025050101         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      vmkl1.smartlearn.lan.

; A records
vmkl1   IN      A       192.168.110.70
vmlf1   IN      A       192.168.110.1
EOF

# Create zone file for smartlearn.dmz
echo -e "${YELLOW}[*] Creating zone file for smartlearn.dmz...${NC}"
cat >/etc/bind/zones/db.smartlearn.dmz <<EOF
\$TTL    86400
@       IN      SOA     vmlm1.smartlearn.dmz. admin.smartlearn.dmz. (
                  2025050101         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      vmlm1.smartlearn.dmz.

; A records
vmlm1   IN      A       192.168.120.60
www     IN      A       192.168.120.60
dns     IN      A       192.168.120.60
vmlf1   IN      A       192.168.120.1
EOF

# Create reverse zone file for 192.168.110.0/24
echo -e "${YELLOW}[*] Creating reverse zone file for 192.168.110.0/24...${NC}"
cat >/etc/bind/zones/db.110.168.192 <<EOF
\$TTL    86400
@       IN      SOA     vmkl1.smartlearn.lan. admin.smartlearn.lan. (
                  2025050101         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      vmkl1.smartlearn.lan.

; PTR Records
70      IN      PTR     vmkl1.smartlearn.lan.
1       IN      PTR     vmlf1.smartlearn.lan.
EOF

# Create reverse zone file for 192.168.120.0/24
echo -e "${YELLOW}[*] Creating reverse zone file for 192.168.120.0/24...${NC}"
cat >/etc/bind/zones/db.120.168.192 <<EOF
\$TTL    86400
@       IN      SOA     vmlm1.smartlearn.dmz. admin.smartlearn.dmz. (
                  2025050101         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      vmlm1.smartlearn.dmz.

; PTR Records
60      IN      PTR     vmlm1.smartlearn.dmz.
60      IN      PTR     www.smartlearn.dmz.
60      IN      PTR     dns.smartlearn.dmz.
1       IN      PTR     vmlf1.smartlearn.dmz.
EOF

# Set proper permissions
echo -e "${YELLOW}[*] Setting proper permissions...${NC}"
chown -R bind:bind /etc/bind/zones
chmod -R 755 /etc/bind/zones

# Check configuration
echo -e "${YELLOW}[*] Checking BIND configuration...${NC}"
named-checkconf /etc/bind/named.conf
if [ $? -eq 0 ]; then
  echo -e "${GREEN}[+] Configuration syntax is valid${NC}"
else
  echo -e "${RED}[-] Configuration syntax error${NC}"
  exit 1
fi

# Check zone files
echo -e "${YELLOW}[*] Checking zone files...${NC}"
named-checkzone smartlearn.lan /etc/bind/zones/db.smartlearn.lan
named-checkzone smartlearn.dmz /etc/bind/zones/db.smartlearn.dmz
named-checkzone 110.168.192.in-addr.arpa /etc/bind/zones/db.110.168.192
named-checkzone 120.168.192.in-addr.arpa /etc/bind/zones/db.120.168.192

# Restart BIND service
echo -e "${YELLOW}[*] Restarting BIND service...${NC}"
systemctl restart bind9
if [ $? -eq 0 ]; then
  echo -e "${GREEN}[+] BIND9 service restarted successfully${NC}"
else
  echo -e "${RED}[-] Failed to restart BIND9 service${NC}"
  systemctl status named
  exit 1
fi

# Enable BIND service to start on boot
echo -e "${YELLOW}[*] Enabling BIND service to start on boot...${NC}"
systemctl enable named

echo -e "${YELLOW}[*] Allowing port 22 through UFW...${NC}"
ufw allow 22/udp

# Final status check
echo -e "${YELLOW}[*] Checking BIND9 service status...${NC}"
systemctl status named --no-pager

echo -e "${GREEN}[+] DNS server has been installed and configured successfully!${NC}"
echo -e "${BLUE}[*] DNS zones configured:${NC}"
echo -e "${BLUE}    - smartlearn.lan${NC}"
echo -e "${BLUE}    - smartlearn.dmz${NC}"
echo -e "${YELLOW}[*] You can verify DNS resolution using:${NC}"
echo -e "${YELLOW}    - nslookup vmkl1.smartlearn.lan 127.0.0.1${NC}"
echo -e "${YELLOW}    - nslookup vmlm1.smartlearn.dmz 127.0.0.1${NC}"
echo -e "${YELLOW}    - nslookup www.smartlearn.dmz 127.0.0.1${NC}"
