# Coturn (TURN/STUN) Server Setup Guide

This guide explains how to configure and deploy the Coturn server for Nextcloud Talk.

## Overview

Coturn provides TURN/STUN services required for Nextcloud Talk to work properly, especially for:
- Peer-to-peer connections behind NAT/firewalls
- WebRTC media streaming
- Voice and video calls

## Architecture

The Coturn setup integrates with your existing infrastructure:

- **Domain**: `turn.okhsunrog.dev`
- **Listening Ports**:
  - `3478` (TCP/UDP) - STUN/TURN (unencrypted)
  - `5349` (TCP/UDP) - TURNS (TLS-encrypted)
- **Relay Ports**: `49152-49252` (UDP) - Unlimited concurrent sessions
- **SSL/TLS**: Let's Encrypt certificates (auto-managed)
- **Authentication**: Static auth secret (secure method for Nextcloud)

Both TURN and TURNS protocols are enabled for maximum client compatibility as recommended by Nextcloud.

## Prerequisites

Before deploying, ensure:

1. ✅ DNS A record pointing `turn.okhsunrog.dev` to your VPS IP
2. ✅ Ports `3478` (TCP/UDP), `5349` (TCP/UDP), and `49152-49252` (UDP) allowed through any upstream firewalls
3. ✅ Ansible vault password configured at `~/.vault_pass`

## Configuration Steps

### 1. Add Static Auth Secret to Vault

The Coturn server uses a static auth secret for authentication. You need to add this to your encrypted vault.

#### Generate a secure random secret:

```bash
openssl rand -hex 32
```

#### Edit the vault:

```bash
ansible-vault edit group_vars/all/vault.yml
```

#### Add the variable:

```yaml
coturn_static_secret: "your-generated-secret-here"
```

Save and exit (`:wq` in vim).

### 2. Verify DNS Configuration

Ensure your DNS is properly configured:

```bash
dig turn.okhsunrog.dev +short
```

This should return your VPS public IP address.

### 3. Deploy Coturn

Run the full Ansible playbook to deploy Coturn:

```bash
ansible-playbook site.yml
```

Or deploy only the coturn role (if already configured):

```bash
ansible-playbook site.yml --tags coturn
```

The playbook will:
- Install coturn package
- Generate configuration from template
- Request Let's Encrypt certificate for `turn.okhsunrog.dev`
- Configure firewall rules (iptables)
- Start and enable the coturn service

### 4. Verify Coturn is Running

SSH into your VPS and check the service status:

```bash
systemctl status coturn
```

Check the logs:

```bash
tail -f /var/log/turnserver/turnserver.log
```

### 5. Test TURN/STUN Server

You can test your TURN server using online tools:

- https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/
  - Add STUN server: `stun:turn.okhsunrog.dev:3478`
  - Add TURN server: `turn:turn.okhsunrog.dev:3478`
  - Add TURNS server: `turns:turn.okhsunrog.dev:5349`
  - Use your static secret for authentication

## Nextcloud Talk Configuration

### Access Nextcloud Admin Settings

1. Log into Nextcloud as admin
2. Go to **Settings** → **Administration** → **Talk**

### Configure TURN/STUN Servers

**Important:** Enter only the domain (e.g., `turn.okhsunrog.dev`), without port number, `http://`, `turn://`, or `turns://` prefixes.

#### TURN server URL:
```
turn.okhsunrog.dev
```

#### Protocol dropdown:
Select **`turn: and turns:`** (this enables both protocols automatically)

#### TURN Secret:
```
your-coturn-static-secret
```
(Use the same secret from your vault)

#### Protocols:
- ✅ UDP and TCP

**Note:** The combined "turn: and turns:" option automatically uses both port 3478 (unencrypted TURN) and port 5349 (TLS-encrypted TURNS) for maximum client compatibility. TURNS provides TLS encryption and works better through restrictive firewalls.

### Save Configuration

Click **Save** and test with a call in Nextcloud Talk.

## Configuration Files Reference

### Main Configuration Variables

File: `group_vars/all/vars.yml`

```yaml
ports:
  external:
    coturn:
      port: 3478
      type: both  # TCP and UDP (TURN)
    coturn_tls:
      port: 5349
      type: both  # TCP and UDP (TURNS)
    coturn_relay_min:
      port: 49152
      type: udp
    coturn_relay_max:
      port: 49252
      type: udp

domains:
  coturn: "turn.okhsunrog.dev"
```

### Coturn Configuration Template

File: `roles/coturn/templates/turnserver.conf.j2`

Key settings:
- **Listening ports**: 3478 (TURN), 5349 (TURNS)
- **Realm**: turn.okhsunrog.dev
- **SSL/TLS**: Let's Encrypt certificates
- **Auth method**: Static auth secret
- **Relay ports**: 49152-49252
- **User quota**: 100 concurrent sessions per user
- **Total quota**: 0 (unlimited)
- **Bandwidth capacity**: 0 (unlimited)

## Troubleshooting

### Check if Coturn is listening

```bash
ss -tulnp | grep -E '(3478|5349)'
```

Expected output:
```
udp   UNCONN 0  0  0.0.0.0:3478  0.0.0.0:*  users:(("turnserver",pid=...))
tcp   LISTEN 0  5  0.0.0.0:3478  0.0.0.0:*  users:(("turnserver",pid=...))
udp   UNCONN 0  0  0.0.0.0:5349  0.0.0.0:*  users:(("turnserver",pid=...))
tcp   LISTEN 0  5  0.0.0.0:5349  0.0.0.0:*  users:(("turnserver",pid=...))
```

### Check firewall rules

```bash
iptables -L INPUT -n -v | grep -E '(3478|5349)'
```

### Certificate issues

If coturn can't access certificates:

```bash
# Check turnserver user is in ssl-cert group
groups turnserver

# Check certificate permissions
ls -la /etc/letsencrypt/live/turn.okhsunrog.dev/
```

### Logs

View detailed logs:

```bash
tail -f /var/log/turnserver/turnserver.log
```

Enable verbose logging (already enabled by default in the configuration).

### Common Issues

**Issue**: Coturn fails to start with certificate errors

**Solution**: Ensure the certificate for `turn.okhsunrog.dev` exists:
```bash
certbot certificates | grep turn.okhsunrog.dev
```

If missing, manually request:
```bash
certbot certonly --standalone -d turn.okhsunrog.dev
```

---

**Issue**: Calls still fail in Nextcloud Talk

**Solution**:
1. Verify TURN server in Nextcloud admin settings
2. Check browser console for WebRTC errors
3. Test with the online ICE tester mentioned above
4. Ensure both UDP and TCP are enabled in Nextcloud

---

**Issue**: Port 3478 already in use

**Solution**: Check what's using the port:
```bash
lsof -i :3478
```

## Security Considerations

1. **Static Secret**: Keep your `coturn_static_secret` secure in the vault
2. **Firewall**: Only required ports are exposed (managed by iptables)
3. **SSL/TLS**: All connections use Let's Encrypt certificates
4. **Quotas**: User and total quotas prevent abuse
5. **No CLI**: CLI interface disabled for security

## Maintenance

### Certificate Renewal

Certificates are automatically renewed via certbot. After renewal, coturn needs restart:

```bash
systemctl restart coturn
```

This is handled automatically by the `certbot_renewal_config` role.

### Updating Configuration

1. Edit variables in `group_vars/all/vars.yml` or vault
2. Modify template in `roles/coturn/templates/turnserver.conf.j2`
3. Redeploy:
   ```bash
   ansible-playbook site.yml --tags coturn
   ```

### Monitoring

Monitor coturn resource usage:

```bash
# Check process
ps aux | grep turnserver

# Check memory usage
systemctl status coturn

# Check active connections
ss -tulnp | grep turnserver
```

## Additional Resources

- [Coturn Documentation](https://github.com/coturn/coturn/wiki)
- [Nextcloud Talk Documentation](https://nextcloud-talk.readthedocs.io/)
- [WebRTC Troubleshooting](https://webrtc.github.io/samples/)

## Summary

Your Coturn server is now integrated into your infrastructure with:

- ✅ Automated deployment via Ansible
- ✅ Automatic SSL/TLS certificate management
- ✅ Firewall rules configured
- ✅ Ready for Nextcloud Talk integration
- ✅ Secure static auth secret authentication
- ✅ Production-ready configuration with quotas and security settings
