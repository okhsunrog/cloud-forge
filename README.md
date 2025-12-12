# Cloud-Forge

Ansible-based infrastructure automation for deploying and managing a VPS with multiple VPN services and web proxies.

## Architecture

The project deploys:
- **VPN Services**: OpenConnect (ocserv) with multiple instances, WireGuard, AmneziaWG
- **Web Infrastructure**: HAProxy load balancer, Nginx reverse proxy with SSL termination
- **Security**: Fail2ban, automated Let's Encrypt certificates, iptables firewall rules
- **Network Configuration**: NAT masquerading, port management, reverse proxy setup

## Requirements

- Ubuntu 22.04 or 24.04 target server
- Ansible 2.9+
- Root SSH access to target server
- Domain names with DNS pointing to server IP

## Quick Start

1. Clone repository:
```bash
git clone https://github.com/okhsunrog/cloud-forge.git
cd cloud-forge
```

2. Configure inventory:
```bash
cp inventory.yml.example inventory.yml
# Edit inventory.yml with your server details
```

3. Configure variables:
```bash
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# Edit group_vars/all/vars.yml for domain and network configuration
# Edit group_vars/all/vault.yml for credentials and user accounts
```

4. Encrypt sensitive data:
```bash
ansible-vault encrypt group_vars/all/vault.yml
```

5. Deploy infrastructure:
```bash
ansible-playbook site.yml --ask-vault-pass
```

## Configuration

### Network Subnets
Edit `group_vars/all/vars.yml`:
```yaml
vpn_subnets:
  ocserv_personal: "10.67.76.0/24"
  ocserv_friends: "10.68.68.0/24"
  wireguard: "10.66.66.0/24"
  amneziawg: "10.65.65.0/24"
```

### Port Configuration
```yaml
ports:
  external:
    wireguard:
      port: 58889
      type: udp
    amneziawg:
      port: 58888
      type: udp
```

### VPN Users
Add users to `group_vars/all/vault.yml`:

**WireGuard peers:**
```yaml
wireguard_peers:
  - name: "client1"
    private_key: "generated_private_key"
    public_key: "generated_public_key"
    ip: "10.66.66.2"
```

**AmneziaWG peers:**
```yaml
amneziawg_peers:
  - name: "client1"
    private_key: "generated_private_key"
    public_key: "generated_public_key"
    ip: "10.65.65.2"
```

**OpenConnect users:**
```yaml
ocserv_users:
  personal:
    - username: "user1"
      password: "password"
```

### Domains
```yaml
domains:
  nginx:
    blog:
      - "example.com"
      - "www.example.com"
```

## Key Generation

**WireGuard:**
```bash
wg genkey | tee private.key | wg pubkey > public.key
```

**AmneziaWG:**
```bash
awg genkey | tee private.key | awg pubkey > public.key
```

## Management Commands

### Full Deployment
```bash
ansible-playbook site.yml
```

Note: Vault password is configured in `ansible.cfg` to use `~/.vault_pass` file. If not using vault password file, add `--ask-vault-pass`.

## Working with Tags

Tags allow you to run specific parts of the playbook without deploying everything.

### List Available Tags
```bash
ansible-playbook site.yml --list-tags
```

### Update Specific Services

**VPN Services:**
```bash
ansible-playbook site.yml --tags ocserv        # OpenConnect VPN
ansible-playbook site.yml --tags wireguard     # WireGuard VPN
ansible-playbook site.yml --tags amneziawg     # AmneziaWG VPN
ansible-playbook site.yml --tags vpn           # All VPN services
```

**Web Services:**
```bash
ansible-playbook site.yml --tags nginx         # Nginx reverse proxy
ansible-playbook site.yml --tags haproxy       # HAProxy load balancer
ansible-playbook site.yml --tags proxy         # Both nginx and haproxy
```

**TURN/STUN Server:**
```bash
ansible-playbook site.yml --tags coturn        # Coturn server
ansible-playbook site.yml --tags coturn,network # Coturn + firewall rules
```

**Certificates:**
```bash
ansible-playbook site.yml --tags certificates  # SSL/TLS certificates
ansible-playbook site.yml --tags certbot       # Just certbot
```

**Security:**
```bash
ansible-playbook site.yml --tags network       # Firewall rules
ansible-playbook site.yml --tags fail2ban      # Intrusion prevention
ansible-playbook site.yml --tags security      # fail2ban
```

**Other:**
```bash
ansible-playbook site.yml --tags base          # Base system config
ansible-playbook site.yml --tags blog          # Blog deployment user
```

### Available Tags Reference

| Tag | Roles/Tasks | Description |
|-----|-------------|-------------|
| `base`, `system` | base_system | Base system configuration |
| `wireguard`, `vpn` | wireguard | WireGuard VPN |
| `amneziawg`, `vpn` | amneziawg | AmneziaWG VPN |
| `ocserv`, `vpn` | ocserv | OpenConnect VPN |
| `coturn`, `turn` | coturn | TURN/STUN for WebRTC |
| `certbot`, `certificates` | certbot, certbot_renewal_config | SSL certificates |
| `haproxy`, `proxy` | haproxy | Load balancer |
| `nginx`, `proxy` | nginx | Reverse proxy |
| `blog`, `deploy` | blog_deploy | Blog deployment |
| `network`, `firewall` | network | iptables firewall |
| `fail2ban`, `security` | fail2ban | IPS |
| `reboot`, `never` | post_tasks | Server reboot (never runs by default) |

### Skip Specific Roles
```bash
ansible-playbook site.yml --skip-tags vpn
ansible-playbook site.yml --skip-tags reboot
```

### Useful Ansible Commands

**Dry run (check what would change):**
```bash
ansible-playbook site.yml --check
ansible-playbook site.yml --tags nginx --check
```

**Verbose output:**
```bash
ansible-playbook site.yml -v     # verbose
ansible-playbook site.yml -vvv   # very verbose
```

**List tasks:**
```bash
ansible-playbook site.yml --list-tasks
ansible-playbook site.yml --tags nginx --list-tasks
```

**Check syntax:**
```bash
ansible-playbook site.yml --syntax-check
```

**Test connectivity:**
```bash
ansible vps -m ping
```

## Ansible Vault Management

**Edit encrypted variables:**
```bash
ansible-vault edit group_vars/all/vault.yml
```

**View encrypted variables:**
```bash
ansible-vault view group_vars/all/vault.yml
```

**Change vault password:**
```bash
ansible-vault rekey group_vars/all/vault.yml
```

## File Structure

```
├── site.yml                    # Main playbook
├── inventory.yml               # Target hosts configuration
├── ansible.cfg                 # Ansible configuration
├── group_vars/all/
│   ├── vars.yml               # Plain variables
│   └── vault.yml              # Encrypted credentials
├── roles/
│   ├── base_system/           # Base system hardening
│   ├── wireguard/             # WireGuard VPN
│   ├── amneziawg/             # AmneziaWG VPN with DPI obfuscation
│   ├── ocserv/                # OpenConnect VPN server
│   ├── nginx/                 # Reverse proxy with SSL
│   ├── haproxy/               # Load balancer
│   ├── certbot/               # Let's Encrypt certificates
│   ├── network/               # Firewall and routing
│   └── fail2ban/              # Intrusion prevention
└── docs/                      # Documentation
```

## Client Configuration

After deployment, client configurations are available at:
- WireGuard: `/etc/wireguard/clients/`
- AmneziaWG: `/etc/amnezia/amneziawg/clients/`

Download configurations:
```bash
scp root@server:/etc/wireguard/clients/client.conf ./
scp root@server:/etc/amnezia/amneziawg/clients/client.conf ./
```

## Customization

### Adding New VPN Instance
1. Add subnet to `vpn_subnets` in `vars.yml`
2. Add port configuration to `ports.external`
3. Update `roles/network/tasks/main.yml` firewall rules
4. Create role or extend existing role configuration

### Modifying SSL Domains
1. Update `domains` section in `vars.yml`
2. Run `ansible-playbook site.yml --tags certificates,nginx`

### Network Isolation
The configuration includes network isolation between VPN networks. Friends VPN network is blocked from accessing other VPN subnets by default.

## Common Workflows

### Add a New VPN User

1. Edit the vault:
   ```bash
   ansible-vault edit group_vars/all/vault.yml
   ```

2. Add user to appropriate VPN section (wireguard_peers, ocserv_users, etc.)

3. Update the VPN service:
   ```bash
   ansible-playbook site.yml --tags ocserv
   # or
   ansible-playbook site.yml --tags wireguard
   ```

### Add a New Domain

1. Add DNS A record pointing to your VPS IP

2. Edit `group_vars/all/vars.yml` and add the domain

3. Deploy certificates and web configuration:
   ```bash
   ansible-playbook site.yml --tags certificates,nginx
   ```

### Update Coturn (TURN/STUN Server)

1. Edit coturn variables in `group_vars/all/vars.yml` or vault

2. Deploy changes:
   ```bash
   ansible-playbook site.yml --tags coturn,network
   ```

See [docs/coturn-setup.md](docs/coturn-setup.md) for complete Coturn setup guide.

### Update Only Firewall Rules

After changing port configuration:
```bash
ansible-playbook site.yml --tags network
```

## Documentation

- [Coturn TURN/STUN Setup](docs/coturn-setup.md) - Complete guide for Nextcloud Talk WebRTC
- [Documentation Index](docs/README.md) - All available documentation

## Troubleshooting

### AmneziaWG DKMS Issues (Ubuntu 24.04)
The playbook automatically fixes Ubuntu 24.04 DKMS compilation issues by adding required source repositories.

### Certificate Renewal
Certificates auto-renew via systemd timer. Check status:
```bash
systemctl status certbot-renewal.timer
```

### VPN Service Issues
```bash
systemctl status wg-quick@wg0           # WireGuard
systemctl status awg-quick@awg0         # AmneziaWG  
systemctl status ocserv-personal        # OpenConnect
```