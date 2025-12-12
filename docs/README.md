# Cloud Forge Documentation

Documentation for the cloud-forge infrastructure automation project.

## Available Guides

- **[Coturn Setup Guide](coturn-setup.md)** - Complete guide for deploying and configuring Coturn (TURN/STUN) server for Nextcloud Talk

## Quick Links

### Project Structure
- Main playbook: `site.yml`
- Inventory: `inventory.yml`
- Variables: `group_vars/all/vars.yml`
- Encrypted secrets: `group_vars/all/vault.yml`
- Ansible configuration: `ansible.cfg`

### Common Commands

Deploy full stack:
```bash
ansible-playbook site.yml
```

Update VPN users only:
```bash
ansible-playbook update_vpn_users.yml
```

Edit vault secrets:
```bash
ansible-vault edit group_vars/all/vault.yml
```

## Infrastructure Components

- **VPN Services**: OpenConnect (ocserv), WireGuard, AmneziaWG
- **Web Proxies**: HAProxy, Nginx with SSL termination
- **Communication**: Coturn (TURN/STUN for Nextcloud Talk)
- **Security**: Fail2ban, iptables firewall
- **Certificates**: Let's Encrypt via certbot

## Adding New Documentation

When adding new components or features, create a new markdown file in this directory and link it in this README.
