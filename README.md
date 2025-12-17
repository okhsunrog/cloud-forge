# Cloud-Forge

Ansible-based infrastructure automation for deploying and managing a dual-VPS architecture with VPN services, reverse proxy, and blog hosting.

## Architecture

The project deploys a dual-VPS setup:

```
                      INTERNET
                          |
          +---------------+---------------+
          |                               |
+-------------------+           +-------------------+
|   Europe VPS      |           |    Moscow VPS     |
|   okhsunrog.dev   |           |   okhsunrog.ru    |
+-------------------+           +-------------------+
| wg-upstream (srv) |<--------->| wg-upstream (cli) |
| 10.77.77.1        |   tunnel  | 10.77.77.2        |
+-------------------+           +-------------------+
| Blog only (nginx) |           | wg-clients (srv)  |
|                   |           | 10.66.66.1        |
+-------------------+           +-------------------+
                                | OpenConnect x2    |
                                | Coturn TURN/STUN  |
                                +-------------------+
                                        |
                            +-----------+-----------+
                            |                       |
                      +----------+            +----------+
                      | Clients  |            | Home Srv |
                      | .10+     |            | .2       |
                      +----------+            +----------+
```

**Moscow VPS (okhsunrog.ru)**:
- Entry point for services
- WireGuard server for clients
- OpenConnect VPN (personal + friends instances)
- Reverse proxy to home server
- Coturn TURN/STUN server
- All client traffic routes through Europe tunnel

**Europe VPS (okhsunrog.dev)**:
- VPN exit node (NAT for Moscow traffic)
- Blog hosting only
- WireGuard upstream server

## Requirements

- Ubuntu 22.04 or 24.04 target servers
- Ansible 2.9+
- Root SSH access to target servers
- Domain names with DNS pointing to server IPs

## Quick Start

1. Clone repository:
```bash
git clone https://github.com/okhsunrog/cloud-forge.git
cd cloud-forge
```

2. Configure variables:
```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# Edit group_vars/all/vault.yml with credentials and WireGuard keys
```

3. Encrypt sensitive data:
```bash
ansible-vault encrypt group_vars/all/vault.yml
```

4. Generate WireGuard keys:
```bash
# For each interface (wg-clients, wg-upstream-moscow, wg-upstream-europe)
wg genkey | tee private.key | wg pubkey > public.key
```

5. Deploy infrastructure:
```bash
# Deploy Europe first (upstream server must be running)
ansible-playbook site-europe.yml

# Then deploy Moscow (connects to Europe)
ansible-playbook site-moscow.yml
```

## Network Configuration

### IP Address Reference

| Subnet | Purpose | Location |
|--------|---------|----------|
| 10.66.66.0/24 | WireGuard clients | Moscow (.1 server, .2 home, .10+ devices) |
| 10.77.77.0/24 | Moscow-Europe tunnel | .1 Europe, .2 Moscow |
| 10.67.76.0/24 | ocserv personal | Moscow |
| 10.68.68.0/24 | ocserv friends | Moscow |

### Domain Distribution

**Moscow VPS (.ru)** - Services:
- `cloud.okhsunrog.ru` - Nextcloud (reverse proxy to home)
- `jellyfin.okhsunrog.ru` - Jellyfin (reverse proxy to home)
- `photoprism.okhsunrog.ru` - PhotoPrism (reverse proxy to home)
- `git.okhsunrog.ru` - Forgejo (reverse proxy to home)
- `turn.okhsunrog.ru` - Coturn TURN/STUN
- `open.okhsunrog.ru` - ocserv personal
- `kafe.okhsunrog.ru` - ocserv friends

**Europe VPS (.dev)** - Blog only:
- `okhsunrog.dev` - Blog

## Management Commands

### Full Deployment

```bash
# Europe VPS
ansible-playbook site-europe.yml

# Moscow VPS
ansible-playbook site-moscow.yml
```

Note: Vault password is configured in `ansible.cfg` to use `~/.vault_pass` file.

### Working with Tags

Tags allow you to run specific parts of the playbook.

**List available tags:**
```bash
ansible-playbook site-moscow.yml --list-tags
```

**Update specific services:**
```bash
# VPN Services (Moscow)
ansible-playbook site-moscow.yml --tags wireguard
ansible-playbook site-moscow.yml --tags ocserv
ansible-playbook site-moscow.yml --tags vpn

# Web Services
ansible-playbook site-moscow.yml --tags nginx
ansible-playbook site-moscow.yml --tags haproxy

# TURN/STUN Server (Moscow)
ansible-playbook site-moscow.yml --tags coturn

# Certificates
ansible-playbook site-europe.yml --tags certificates

# Network/Firewall
ansible-playbook site-moscow.yml --tags network
```

### Available Tags Reference

| Tag | Roles/Tasks | Description |
|-----|-------------|-------------|
| `base`, `system` | base_system | Base system configuration |
| `wireguard`, `vpn` | wireguard | WireGuard VPN |
| `ocserv`, `vpn` | ocserv | OpenConnect VPN (Moscow only) |
| `coturn`, `turn` | coturn | TURN/STUN for WebRTC (Moscow only) |
| `certbot`, `certificates` | certbot, certbot_renewal_config | SSL certificates |
| `haproxy`, `proxy` | haproxy | Load balancer |
| `nginx`, `proxy` | nginx | Reverse proxy |
| `blog`, `deploy` | blog_deploy | Blog deployment (Europe only) |
| `network`, `firewall` | network | iptables firewall |
| `fail2ban`, `security` | fail2ban | IPS |
| `reboot`, `never` | post_tasks | Server reboot (never runs by default) |

### Useful Ansible Commands

```bash
# Dry run
ansible-playbook site-moscow.yml --check

# Verbose output
ansible-playbook site-moscow.yml -v

# List tasks
ansible-playbook site-moscow.yml --list-tasks

# Test connectivity
ansible moscow -m ping
ansible europe -m ping
```

## Configuration

### Vault Variables

Edit `group_vars/all/vault.yml`:

```yaml
# Host credentials
vault_moscow_ip: "x.x.x.x"
vault_moscow_root_password: "..."
vault_europe_ip: "y.y.y.y"
vault_europe_root_password: "..."

# WireGuard keys
vault_wg_clients_private_key: "..."
vault_wg_upstream_moscow_private_key: "..."
vault_wg_upstream_europe_private_key: "..."
vault_wg_upstream_europe_public_key: "..."

# WireGuard peers
vault_wg_clients_peers:
  - name: "home-server"
    private_key: "..."
    public_key: "..."
    ip: "10.66.66.2"

vault_wg_upstream_europe_peers:
  - name: "moscow"
    public_key: "..."
    ip: "10.77.77.2"
    allowed_ips: "10.77.77.2/32,10.66.66.0/24,10.67.76.0/24,10.68.68.0/24"

# OpenConnect users
ocserv_users:
  personal:
    - username: "user1"
      password: "password"
```

### Host-Specific Configuration

- `group_vars/moscow/vars.yml` - Moscow VPS configuration
- `group_vars/europe/vars.yml` - Europe VPS configuration

## File Structure

```
├── site-moscow.yml             # Moscow VPS playbook
├── site-europe.yml             # Europe VPS playbook
├── inventory.yml               # Target hosts configuration
├── ansible.cfg                 # Ansible configuration
├── group_vars/
│   ├── all/
│   │   ├── vars.yml           # Shared variables
│   │   └── vault.yml          # Encrypted credentials
│   ├── moscow/
│   │   └── vars.yml           # Moscow-specific vars
│   └── europe/
│       └── vars.yml           # Europe-specific vars
├── generated_configs/
│   └── home-server/           # Generated WG config for home server
├── roles/
│   ├── base_system/           # Base system hardening
│   ├── wireguard/             # WireGuard VPN (multi-interface)
│   ├── ocserv/                # OpenConnect VPN server
│   ├── nginx/                 # Reverse proxy with SSL
│   ├── haproxy/               # Load balancer
│   ├── certbot/               # Let's Encrypt certificates
│   ├── coturn/                # TURN/STUN server
│   ├── blog_deploy/           # Blog deployment
│   ├── network/               # Firewall and routing
│   └── fail2ban/              # Intrusion prevention
└── docs/                       # Documentation
```

## Deployment Order

1. Generate WireGuard keys for all interfaces
2. Deploy Europe VPS first (upstream server must be running)
3. Deploy Moscow VPS (upstream client connects to Europe)
4. Copy generated home server config from `generated_configs/home-server/`
5. Test traffic routing: Moscow → Europe → Internet

## Client Configuration

After deployment, client configurations are available at:
- WireGuard (Moscow): `/etc/wireguard/wg-clients/clients/`
- Home server config: `generated_configs/home-server/wg-client.conf`

## Key Generation

```bash
# WireGuard keys
wg genkey | tee private.key | wg pubkey > public.key

# Coturn secret
openssl rand -hex 32
```

## Common Workflows

### Add a New VPN Client (Moscow)

1. Generate WireGuard keys
2. Edit vault and add to `vault_wg_clients_peers`
3. Run: `ansible-playbook site-moscow.yml --tags wireguard`

### Add a New OpenConnect User

1. Edit vault and add to `ocserv_users`
2. Run: `ansible-playbook site-moscow.yml --tags ocserv`

### Update Blog (Europe)

```bash
ansible-playbook site-europe.yml --tags blog
```

## Troubleshooting

### Check WireGuard Tunnel

```bash
# On Moscow
wg show wg0  # clients
wg show wg1  # upstream to Europe

# On Europe
wg show wg0  # upstream server
```

### Certificate Renewal

```bash
systemctl status certbot-renewal.timer
```

### VPN Service Status

```bash
# Moscow
systemctl status wg-quick@wg0
systemctl status wg-quick@wg1
systemctl status ocserv-personal
systemctl status ocserv-friends

# Europe
systemctl status wg-quick@wg0
```

## Documentation

- [Coturn TURN/STUN Setup](docs/coturn-setup.md) - Complete guide for Nextcloud Talk WebRTC
