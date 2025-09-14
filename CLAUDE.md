# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is an Ansible-based infrastructure automation project for deploying and managing a VPS with multiple VPN services and web proxies. The project uses Ansible playbooks to configure:

- **VPN Services**: OpenConnect (ocserv) with multiple instances, WireGuard
- **Web Infrastructure**: HAProxy load balancer, Nginx reverse proxy with SSL termination
- **Security**: Fail2ban, automated Let's Encrypt certificates
- **Network Configuration**: iptables rules, port management, reverse proxy setup

## Key Commands

### Main Deployment
- `ansible-playbook site.yml` - Deploy full infrastructure stack
- `ansible-playbook update_vpn_users.yml` - Update VPN user configurations only

### Configuration Management
- Encrypted variables stored in `group_vars/all/vault.yml` using Ansible Vault
- Plain variables in `group_vars/all/vars.yml`
- Vault password file configured at `~/.vault_pass`

## Project Structure

### Core Files
- `site.yml` - Main playbook orchestrating all roles
- `inventory.yml` - Defines target hosts (uses vault variables for IPs/credentials)
- `ansible.cfg` - Ansible configuration with vault settings
- `update_vpn_users.yml` - Dedicated playbook for VPN user management

### Roles Architecture
The project uses a modular role-based structure in `roles/`:

- `base_system` - Base system configuration and hardening
- `wireguard` - WireGuard VPN server setup
- `ocserv` - OpenConnect VPN server with multi-instance support
- `certbot` - Let's Encrypt certificate management
- `certbot_renewal_config` - Certificate auto-renewal configuration
- `haproxy` - Load balancer configuration
- `nginx` - Reverse proxy with SSL termination
- `network` - iptables and network rules
- `fail2ban` - Intrusion prevention system

### Configuration Variables
Key configuration patterns in `group_vars/all/vars.yml`:
- `vpn_subnets` - CIDR blocks for different VPN networks
- `ports` - Centralized port management (external/internal)
- `domains` - Domain mappings for different services
- `reverse_proxy` - Backend service configuration
- `ocserv_instances` - Multi-instance VPN configuration

## Development Notes

- The playbook requires Ubuntu 22.04+ and includes OS version validation
- Multi-instance ocserv configuration allows separate VPN endpoints with different policies
- Network configuration supports NAT masquerading for VPN subnets
- SSL certificates are automatically managed via Let's Encrypt
- The system includes automatic reboot after full deployment
- Reverse proxy setup enables hosting multiple services behind a single public IP