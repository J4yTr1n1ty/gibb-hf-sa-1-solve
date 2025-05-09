# Solve scripts

## Usage

### Server hardening

```bash
curl -o solve.sh https://raw.githubusercontent.com/J4yTr1n1ty/gibb-hf-sa-1-solve/refs/heads/main/solve.sh
chmod +x solve.sh
sudo ./solve.sh
```

#### Verify successful hardening

```bash
curl -o verify-hardening.sh https://raw.githubusercontent.com/J4yTr1n1ty/gibb-hf-sa-1-solve/refs/heads/main/verify-hardening.sh
chmod +x verify-hardening.sh
sudo ./verify-hardening.sh
```

##### Checklist

- [ ] Automatic updates are enabled `sudo systemctl status unattended-upgrades`
- [ ] SSH is running on a custom port `sudo systemctl status ssh`
  - [ ] `Port 23344`
- [ ] SSH password authentication is disabled (key-only authentication) `cat /etc/ssh/sshd_config`
  - [ ] `PasswordAuthentication no`
  - [ ] `PubkeyAuthentication yes`
- [ ] UFW configured `sudo ufw status verbose`
  - [ ] UFW is active
  - [ ] Default deny incoming
  - [ ] Allow port 23344

### DNS

```bash
curl -o solve-dns.sh https://raw.githubusercontent.com/J4yTr1n1ty/gibb-hf-sa-1-solve/refs/heads/main/solve-dns.sh
chmod +x solve-dns.sh
sudo ./solve-dns.sh
```

#### Verify successful Setup of DNS

```bash
curl -o verify-dns.sh https://raw.githubusercontent.com/J4yTr1n1ty/gibb-hf-sa-1-solve/refs/heads/main/verify-dns.sh
chmod +x verify-dns.sh
sudo ./verify-dns.sh
```
