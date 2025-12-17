# Dual-VPS Setup Guide

## Prerequisites

- SSH key access to both servers (already configured)
- Domain DNS records pointing to correct IPs:
  - `okhsunrog.ru` → Moscow VPS IP
  - `okhsunrog.dev` → Europe VPS IP

## Step 1: Generate WireGuard Keys

You need keys for 3 interfaces + peers. Run these commands locally:

```bash
# Create a temporary directory for key generation
mkdir -p ~/wg-keys && cd ~/wg-keys

# 1. Europe upstream server (wg0 on Europe)
wg genkey | tee europe-upstream.key | wg pubkey > europe-upstream.pub

# 2. Moscow upstream client (wg1 on Moscow, connects to Europe)
wg genkey | tee moscow-upstream.key | wg pubkey > moscow-upstream.pub

# 3. Moscow clients server (wg0 on Moscow, serves home + devices)
wg genkey | tee moscow-clients.key | wg pubkey > moscow-clients.pub

# 4. Home server peer (connects to Moscow wg0)
wg genkey | tee home-server.key | wg pubkey > home-server.pub

# 5. Any additional client devices
wg genkey | tee phone.key | wg pubkey > phone.pub
wg genkey | tee laptop.key | wg pubkey > laptop.pub
```

## Step 2: Display Keys for Copying

```bash
cd ~/wg-keys
echo "=== Europe Upstream (wg0 on Europe) ==="
echo "Private: $(cat europe-upstream.key)"
echo "Public:  $(cat europe-upstream.pub)"

echo -e "\n=== Moscow Upstream (wg1 on Moscow) ==="
echo "Private: $(cat moscow-upstream.key)"
echo "Public:  $(cat moscow-upstream.pub)"

echo -e "\n=== Moscow Clients (wg0 on Moscow) ==="
echo "Private: $(cat moscow-clients.key)"
echo "Public:  $(cat moscow-clients.pub)"

echo -e "\n=== Home Server Peer ==="
echo "Private: $(cat home-server.key)"
echo "Public:  $(cat home-server.pub)"

echo -e "\n=== Phone Peer ==="
echo "Private: $(cat phone.key)"
echo "Public:  $(cat phone.pub)"

echo -e "\n=== Laptop Peer ==="
echo "Private: $(cat laptop.key)"
echo "Public:  $(cat laptop.pub)"
```

## Step 3: Update Vault

Edit your vault file:

```bash
ansible-vault edit group_vars/all/vault.yml
```

Add the following structure (replace with your actual keys):

```yaml
---
# WireGuard keys for wg-clients interface (Moscow server, wg0)
vault_wg_clients_private_key: "<moscow-clients.key contents>"

# WireGuard keys for upstream tunnel
vault_wg_upstream_moscow_private_key: "<moscow-upstream.key contents>"
vault_wg_upstream_europe_private_key: "<europe-upstream.key contents>"
vault_wg_upstream_europe_public_key: "<europe-upstream.pub contents>"

# Peers for wg-clients (Moscow wg0) - home server + client devices
vault_wg_clients_peers:
  - name: "home-server"
    private_key: "<home-server.key contents>"
    public_key: "<home-server.pub contents>"
    ip: "10.66.66.2"
  - name: "phone"
    private_key: "<phone.key contents>"
    public_key: "<phone.pub contents>"
    ip: "10.66.66.10"
  - name: "laptop"
    private_key: "<laptop.key contents>"
    public_key: "<laptop.pub contents>"
    ip: "10.66.66.11"

# Peers for upstream tunnel (Europe wg0) - Moscow is the only peer
vault_wg_upstream_europe_peers:
  - name: "moscow"
    public_key: "<moscow-upstream.pub contents>"
    ip: "10.77.77.2"
    allowed_ips: "10.77.77.2/32,10.66.66.0/24,10.67.76.0/24,10.68.68.0/24"

# OpenConnect users (Moscow VPS)
ocserv_users:
  personal:
    - username: "your_username"
      password: "your_password"
  friends:
    - username: "friend_name"
      password: "friend_password"

# Coturn secret (generate with: openssl rand -hex 32)
coturn_static_secret: "<run: openssl rand -hex 32>"
```

## Step 4: Deploy

**Important: Deploy Europe first!** The Moscow upstream client needs Europe's WireGuard server running.

```bash
# 1. Deploy Europe VPS (upstream WireGuard server + blog)
ansible-playbook site-europe.yml

# 2. Deploy Moscow VPS (connects to Europe, serves clients)
ansible-playbook site-moscow.yml
```

## Step 5: Get Home Server Config

After Moscow deployment, the home server WireGuard config is fetched to:

```
generated_configs/home-server/wg-client.conf
```

Copy this file to your home server and:

```bash
# On home server
sudo cp wg-client.conf /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
```

## Step 6: Verify Tunnel

```bash
# On Moscow - check both interfaces
ssh ubuntu@okhsunrog.ru
sudo wg show

# Should show:
# - wg0 (clients): peers including home-server
# - wg1 (upstream): connected to Europe

# On Europe - check upstream server
ssh root@okhsunrog.dev
sudo wg show

# Should show:
# - wg0 (upstream): Moscow as peer with handshake
```

## Network Topology Reference

```
Internet
    │
    ├── Europe VPS (okhsunrog.dev)
    │   └── wg0: 10.77.77.1/24 (upstream server)
    │           └── peer: Moscow (10.77.77.2)
    │
    └── Moscow VPS (okhsunrog.ru)
        ├── wg0: 10.66.66.1/24 (clients server)
        │       ├── peer: home-server (10.66.66.2)
        │       ├── peer: phone (10.66.66.10)
        │       └── peer: laptop (10.66.66.11)
        │
        └── wg1: 10.77.77.2/24 (upstream client)
                └── connects to Europe wg0

Traffic flow:
  Client devices → Moscow wg0 → policy routing → Moscow wg1 → Europe wg0 → Internet
```

## Troubleshooting

### WireGuard not connecting

```bash
# Check logs
sudo journalctl -u wg-quick@wg0 -f

# Verify keys match
sudo wg show
```

### Tunnel routing not working

```bash
# On Moscow, check routing service
sudo systemctl status tunnel-routing

# Check policy rules
ip rule show
ip route show table tunnel
```

### Certificates failing

```bash
# Check certbot logs
sudo journalctl -u snap.certbot.renew -f

# Manually test
sudo certbot certificates
```
