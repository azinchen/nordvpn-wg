## Connection Problems

### VPN won't connect

**Symptoms:** Container starts but the tunnel never comes up, or it crash-loops.

**Check:**
1. **Token:** Verify `TOKEN` is a valid, unexpired NordVPN access token. `CRITICAL: TOKEN is not set` or `could not obtain WireGuard private key from NordVPN API` means the token is missing/invalid. See [Getting a Token](https://github.com/azinchen/nordvpn-wg#getting-a-token).
2. **Logs:** `docker logs vpn` — look for the `[VPN-CONFIG]` and `[SERVICE-NORDVPN]` lines.
3. **API access:** The container needs HTTPS access to NordVPN API IPs during bootstrap. Behind a corporate proxy/firewall, ensure TCP/443 to the `NORDVPNAPI_IP` addresses is allowed.
4. **WireGuard engine:** The image prefers the host's kernel WireGuard module (5.6+ built in, or the `wireguard` module loaded). On kernels without it, the container falls back to userspace `wireguard-go` — that fallback needs `--device /dev/net/tun`, otherwise startup fails. Look for `Falling back to slow userspace implementation` in the logs, and check the active engine with `network-diagnostic` (`WireGuard Engine` line). See [Permissions](Permissions).
5. **Capabilities:** WireGuard needs `NET_ADMIN` plus the `net.ipv4.conf.all.src_valid_mark=1` sysctl (or `privileged: true`) so `wg-quick` can set its routing policy. `SYS_ADMIN` is not required.

### `VPN connected successfully` but no traffic

**Symptoms:** `wg0` exists but nothing flows.

**Check:**
1. **Handshake:** `docker exec vpn wg show wg0`. If you see `0 B received` and no `latest handshake`, the NordLynx handshake isn't completing — usually a transient/overloaded server or rate-limiting. Wait for the health/scheduled reconnect, or restart to pick a new server.
2. **Firewall:** `docker exec vpn iptables -S OUTPUT` — verify the `-o wg0 -j ACCEPT` rule exists.
3. **Diagnostics:** `docker exec vpn /usr/local/bin/network-diagnostic`

### Connection drops frequently

**Fix:** Use health monitoring and scheduled switching:
```yaml
environment:
  - CHECK_CONNECTION_CRON=*/5 * * * *
  - CHECK_CONNECTION_URL=https://1.1.1.1
  - RECREATE_VPN_CRON=0 */6 * * *
```

See [Automatic Reconnection](Automatic-Reconnection#connection-health-monitoring) for details.

## Networking Problems

### Containers behind VPN have no network

**Symptoms:** `docker exec app curl https://example.com` fails.

**Check:**
1. **VPN is up:** `docker exec vpn wg show wg0` — confirm a recent handshake.
2. **DNS:** `docker exec vpn cat /etc/resolv.conf` — should list the VPN DNS servers the container wrote (default `103.86.96.100` / `103.86.99.100`, or your `DNS` override). See [Custom DNS](Custom-DNS).
3. **Firewall:** `docker exec vpn iptables -S` — verify the OUTPUT chain allows traffic via wg0.

### Can't access containers from LAN

**Fix:** Set `NETWORK` to include your LAN CIDR:
```bash
-e NETWORK=192.168.1.0/24
```

Docker subnets are **not** auto-allowed. If inter-container communication is needed, include Docker's subnet too.

### Torrent client stalled despite a healthy swarm

**Symptoms:** qBittorrent (or another libtorrent-based client) running with `network_mode: "service:vpn"` shows torrents as **stalled** with 0 peers, while the swarm has plenty of seeds. Ordinary outbound traffic from the namespace (e.g. `curl`) works fine.

**Cause:** libtorrent binds its listen sockets — including DHT and the per-socket tracker announces — to the interfaces that exist **when the client starts**. If the client comes up before `wg0` does (typical: both containers start together and WireGuard needs a few seconds), it binds only `lo` and `eth0`. Tracker announces and DHT queries from the `eth0`-bound sockets are blocked by the kill switch (by design), so the client never discovers any peers — even though unbound outgoing connections still route through the tunnel. The `RECREATE_VPN_CRON` interface swap has the same effect on a previously working binding.

**Fix:** Bind the client explicitly to the tunnel interface. In qBittorrent: **Settings → Advanced → Network interface → `wg0`** (stored as `Session\Interface=wg0`, or set `current_network_interface=wg0` via the WebUI API). libtorrent tracks the interface by name and re-binds automatically each time `wg0` is recreated on reconnect.

**Verify:** inside the namespace, `netstat -tln | grep 6881` should show the listen socket on the wg0 address (e.g. `10.5.0.2:6881`); then force a reannounce and peers should appear.

### DNS leaks

**Check:**
1. Run diagnostics: `docker exec vpn /usr/local/bin/network-diagnostic`
2. Look at the DNS section — nameservers should be VPN-provided addresses, reached over `wg0`
3. If using IPv6, it may bypass the VPN. See [IPv6 Configuration](IPv6-Configuration)

### NETWORK setting defeats the kill switch

**Cause:** `NETWORK` CIDRs are always allowed, regardless of VPN state. If you set `NETWORK=0.0.0.0/0`, **all traffic bypasses the VPN**.

**Fix:** Keep `NETWORK` as narrow as possible — only include your LAN subnet and any Docker networks that need direct access.

## Firewall & Permissions

### iptables errors on container start

**Symptoms:** Errors like `iptables: No chain/target/match by that name` or `Permission denied`.

**Check:**
1. **NET_ADMIN capability:** Ensure `--cap-add=NET_ADMIN` is set.
2. **Kernel compatibility:** The container auto-detects nft vs legacy. Check logs for `[ENTRYPOINT] Using IPv4 backend:` to see which was selected.
3. **Host iptables/WireGuard modules:** Some minimal hosts (e.g., certain NAS devices) may lack required kernel modules.

### `wg-quick` fails to set routing / `src_valid_mark`

Pass the `net.ipv4.conf.all.src_valid_mark=1` sysctl (or run `privileged: true`). `wg-quick` tries to set this itself but can't inside a container with a read-only `/proc/sys`, so Docker must set it. See the compose snippet in [Docker Compose Examples](Docker-Compose-Examples).

## Scheduling

### Cron jobs not running

**Check:**
1. **Syntax:** Valid cron format (5 fields). Invalid expressions are silently ignored by crond.
2. **Logs:** Look for `[INIT-SETUPCRON]` lines at startup — they show the parsed schedule in human-readable format.
3. **Crontab:** `docker exec vpn cat /var/spool/cron/crontabs/root`

## Diagnostics

### Built-in Network Diagnostics

Enable automatic diagnostics on every VPN connection:

```bash
-e NETWORK_DIAGNOSTIC_ENABLED=true
```

Or run manually:

```bash
docker exec vpn /usr/local/bin/network-diagnostic          # full diagnostics
docker exec vpn /usr/local/bin/network-diagnostic --basic   # IP + location only
```

The diagnostic tool checks: public IP and geolocation, WireGuard status, network interfaces, firewall rules, DNS nameservers, IP routing table, and kernel version.

### Reading Container Logs

```bash
docker logs vpn              # full logs
docker logs -f vpn           # follow in real-time
docker logs --tail 50 vpn    # last 50 lines
```

Key log messages:

| Log message | Meaning |
|------------|---------|
| `[ENTRYPOINT] Using IPv4 backend: ...` | Firewall backend selected |
| `[VPN-CONFIG] Selected server ...` | Selected VPN server |
| `[SERVICE-NORDVPN] VPN connected successfully` | `wg0` came up (verify with a handshake) |
| `[SERVICE-NORDVPN] VPN connection timeout` | Tunnel didn't establish in time |
| `[HEALTHCHECK] Connection check failed` | Health check triggered reconnection |

### Inspecting the Container

```bash
docker exec vpn wg show wg0                  # WireGuard peer/handshake/transfer
docker exec vpn ip route                     # view routing table
docker exec vpn iptables -S                   # check iptables rules
docker exec vpn cat /etc/resolv.conf          # active DNS servers
docker exec vpn env | sort                    # check environment
```
