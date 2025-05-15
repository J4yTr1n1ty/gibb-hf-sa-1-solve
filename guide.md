# Manual Setup Guide

> OUT OF DATE

This guide provides step-by-step instructions for server hardening and DNS setup without using the automated scripts.

## Server Hardening Guide

### 1. Install and Configure Automatic Updates

```bash
sudo apt-get update
sudo apt-get install -y unattended-upgrades
sudo systemctl enable unattended-upgrades
sudo systemctl restart unattended-upgrades
```

#### Verify unattended-upgrades

```bash
sudo systemctl status unattended-upgrades
```

### 2. Harden SSH Configuration

```bash
# Backup original SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Create new SSH config file
sudo vim /etc/ssh/sshd_config
```

In Vim, press `i` to enter insert mode and add the following content:

```
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
```

Save and exit Vim by pressing `Esc`, then typing `:wq` and pressing `Enter`.

Restart SSH:

```bash
sudo systemctl restart ssh
```

Check if SSH is running on port 23344:

```bash
sudo systemctl status ssh
```

For me, sometimes it would not take effect unless I restarted the machine.

### 3. Configure UFW Firewall

```bash
sudo apt-get install -y ufw
sudo ufw --force reset
sudo ufw default deny
sudo ufw allow 23344/tcp
sudo ufw enable
```

## DNS Server Setup Guide

### 1. Install BIND9 DNS Server

```bash
sudo apt-get update
sudo apt-get install -y bind9 bind9utils bind9-doc
```

### 2. Configure BIND Options

```bash
# Backup original configurations
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bak

# Create new options file
sudo vim /etc/bind/named.conf.options
```

In Vim, add:

```
options {
    directory "/var/cache/bind";

    // Allow queries from local networks only
    allow-query {
        localhost;
        192.168.110.0/24;
        192.168.120.0/24;
    };

    // Forward DNS queries if this server doesn't have the answer
    forwarders {
        1.1.1.1;
        8.8.8.8;
        8.8.4.4;
    };

    listen-on-v6 { any; };

    // Security settings
    auth-nxdomain no;
    version none;
    dnssec-validation no;
};
```

### 3. Configure Local Zones

```bash
sudo vim /etc/bind/named.conf.local
```

Add:

```
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
```

### 4. Create Zone Files

```bash
sudo mkdir -p /etc/bind/zones
```

#### Create zone file for smartlearn.lan

```bash
sudo vim /etc/bind/zones/db.smartlearn.lan
```

Add:

```
$TTL    86400
@       IN      SOA     dns.smartlearn.dmz. admin.smartlearn.dmz. (
                           2         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      dns.smartlearn.dmz.

; A records
dns      IN      A       192.168.120.60
vmkl1   IN      A       192.168.110.70
vmlf1   IN      A       192.168.110.1
```

#### Create zone file for smartlearn.dmz

```bash
sudo vim /etc/bind/zones/db.smartlearn.dmz
```

Add:

```
$TTL    86400
@       IN      SOA     dns.smartlearn.dmz. admin.smartlearn.dmz. (
                           2         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      dns.smartlearn.dmz.

; A records
vmlm1   IN      A       192.168.120.60
www     IN      A       192.168.120.60
dns     IN      A       192.168.110.60
vmlf1   IN      A       192.168.120.1
```

#### Create reverse zone file for 192.168.110.0/24

```bash
sudo vim /etc/bind/zones/db.110.168.192
```

Add:

```
$TTL    86400
@       IN      SOA     dns.smartlearn.dmz. admin.smartlearn.dmz. (
                           2         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      dns.smartlearn.dmz.

; PTR Records
60      IN      PTR     dns.smartlearn.dmz.
70      IN      PTR     vmkl1.smartlearn.lan.
1       IN      PTR     vmlf1.smartlearn.lan.
```

#### Create reverse zone file for 192.168.120.0/24

```bash
sudo vim /etc/bind/zones/db.120.168.192
```

Add:

```
$TTL    86400
@       IN      SOA     dns.smartlearn.dmz. admin.smartlearn.dmz. (
                           2         ; Serial
                        3600         ; Refresh
                        1800         ; Retry
                       604800         ; Expire
                        86400 )      ; Negative Cache TTL

; Name servers
@       IN      NS      dns.smartlearn.dmz.

; PTR Records
60      IN      PTR     vmlm1.smartlearn.dmz.
60      IN      PTR     www.smartlearn.dmz.
60      IN      PTR     dns.smartlearn.dmz.
1       IN      PTR     vmlf1.smartlearn.dmz.
```

### 5. Set Permissions and Start BIND

```bash
sudo chown -R bind:bind /etc/bind/zones
sudo chmod -R 755 /etc/bind/zones
sudo named-checkconf /etc/bind/named.conf
sudo systemctl restart bind9
sudo systemctl enable named
sudo ufw allow 53/udp
```

## Banner Grabbing

This section explains how you can use Netcat to grab banners from HTTP and DNS servers.

### 1. HTTP Servers

```bash
nc 192.168.110.60 80
HEAD / HTTP/1.1
```

### 2. DNS Servers

```bash
echo -ne "\x00\x1c\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07\x76\x65\x72\x73\x69\x6f\x6e\x04\x62\x69\x6e\x64\x00\x00\x10\x00\x03" | nc -u <DNS_SERVER_IP> 53 | xxd -g 1
```
