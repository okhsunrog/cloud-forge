# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is an Ansible-based infrastructure automation project for deploying and managing a dual-VPS architecture:

**Moscow VPS (msk.okhsunrog.ru)**:
- Entry point for all services
- WireGuard server for clients (wg0) + upstream client to Europe (wg1)
- OpenConnect VPN with multiple instances (personal, friends)
- Reverse proxy to home server via WireGuard
- Coturn TURN/STUN server
- Blog hosting
- All client traffic routes through Europe tunnel

**Europe VPS (eu.okhsunrog.dev)**:
- VPN exit node only (NAT for Moscow traffic)
- WireGuard upstream server

## Key Commands

### Main Deployment
- `ansible-playbook site-europe.yml` - Deploy Europe VPS (deploy first)
- `ansible-playbook site-moscow.yml` - Deploy Moscow VPS (deploy after Europe)

### Selective Deployment with Tags
- `ansible-playbook site-moscow.yml --tags wireguard,amneziawg,network && ansible-playbook site-moscow.yml --tags fetch-configs` - Add/update WireGuard peers (includes network to apply firewall rules for untrusted peers)
- `ansible-playbook site-moscow.yml --tags wireguard` - Update WireGuard config only (no firewall changes)
- `ansible-playbook site-moscow.yml --tags amneziawg` - Update AmneziaWG config
- `ansible-playbook site-moscow.yml --tags network` - Update firewall rules, NAT, and tunnel routing
- `ansible-playbook site-moscow.yml --tags ocserv` - Update OpenConnect users
- `ansible-playbook site-moscow.yml --tags fetch-configs` - Pull client configs to local
- `ansible-playbook site-moscow.yml --tags blog` - Update blog

**Important**: When adding untrusted WireGuard peers, always include the `network` tag to apply iptables rules that block them from accessing internal VPN subnets.

### Configuration Management
- Encrypted variables stored in `group_vars/all/vault.yml` using Ansible Vault
- Shared variables in `group_vars/all/vars.yml`
- Host-specific variables in `group_vars/moscow/vars.yml` and `group_vars/europe/vars.yml`
- Vault password file configured at `~/.vault_pass`

## Project Structure

### Core Files
- `site-moscow.yml` - Moscow VPS playbook (services, VPN, reverse proxy, blog)
- `site-europe.yml` - Europe VPS playbook (VPN exit node only)
- `inventory.yml` - Defines target hosts (msk.okhsunrog.ru, eu.okhsunrog.dev)
- `ansible.cfg` - Ansible configuration with vault settings

### Roles Architecture
The project uses a modular role-based structure in `roles/`:

- `base_system` - Base system configuration and hardening
- `wireguard` - WireGuard VPN (supports multiple interfaces per host)
- `amneziawg` - AmneziaWG VPN for DPI bypass (Moscow only, reuses WireGuard keys)
- `ocserv` - OpenConnect VPN server with multi-instance support (Moscow only)
- `certbot` - Let's Encrypt certificate management
- `certbot_renewal_config` - Certificate auto-renewal configuration
- `haproxy` - Load balancer configuration
- `nginx` - Reverse proxy with SSL termination
- `blog_deploy` - Blog deployment (Moscow only)
- `coturn` - TURN/STUN server (Moscow only)
- `network` - iptables, NAT, and tunnel routing
- `fail2ban` - Intrusion prevention system

### Configuration Variables

**Shared (`group_vars/all/vars.yml`)**:
- `wg_networks` - WireGuard subnet definitions
- `email` - Let's Encrypt email
- `sysctl_settings` - Kernel parameters

**Moscow-specific (`group_vars/moscow/vars.yml`)**:
- `wireguard_interfaces` - wg-clients (server) + wg-upstream (client)
- `ocserv_instances` - OpenConnect VPN instances
- `reverse_proxy` - Backend service configuration (to home server)
- `route_through_tunnel: true` - Enable policy routing through Europe

**Europe-specific (`group_vars/europe/vars.yml`)**:
- `wireguard_interfaces` - wg-upstream (server)
- `vpn_subnets` - NAT configuration for Moscow traffic

### Network Topology

```
10.65.65.0/24 - AmneziaWG clients (Moscow: .1, same peers as WireGuard)
10.66.66.0/24 - WireGuard clients (Moscow: .1, home: .2, devices: .3+)
10.77.77.0/24 - Moscow-Europe tunnel (.1 Europe, .2 Moscow)
10.67.76.0/24 - ocserv personal (Moscow)
10.68.68.0/24 - ocserv friends (Moscow)
```

## DNS and Domains

Stable subdomains for infrastructure (always point to same server):
- `msk.okhsunrog.ru` → Moscow VPS IP
- `eu.okhsunrog.dev` → Europe VPS IP

User-facing domains (can be changed):
- `okhsunrog.ru`, `okhsunrog.dev` → Currently point to Moscow (blog)
- `*.okhsunrog.ru`, `*.okhsunrog.dev` → Service subdomains on Moscow

## Development Notes

- Deploy Europe first (upstream server must be running before Moscow connects)
- WireGuard role now supports multiple interfaces via `wireguard_interfaces` list
- Network role includes policy routing for Moscow (routes VPN traffic through Europe tunnel)
- The playbook requires Ubuntu 22.04+ and includes OS version validation
- SSL certificates are automatically managed via Let's Encrypt
- Generated client configs saved to `generated_configs/wireguard-clients/` and `generated_configs/amneziawg-clients/`
