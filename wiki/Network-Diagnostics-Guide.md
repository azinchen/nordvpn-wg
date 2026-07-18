The container includes a built-in diagnostic tool at `/usr/local/bin/network-diagnostic` that provides comprehensive network and VPN status information for a WireGuard-connected system.

## Running Diagnostics

### Automatic (on every connection)

```bash
-e NETWORK_DIAGNOSTIC_ENABLED=true
```

### Manual

```bash
# Full diagnostics
docker exec vpn /usr/local/bin/network-diagnostic

# Quick IP + location check only
docker exec vpn /usr/local/bin/network-diagnostic --basic
```

## Modes

### `--basic` Mode

Outputs a single line:

```
Public IP address 203.0.113.42, location Amsterdam NL
```

Returns exit code 0 on success, 1 if the public IP couldn't be determined.

### `--full` Mode (default)

Produces a comprehensive report covering all sections below.

## Output Sections (Full Mode)

### Header & VPN Status

```
WireGuard DIAG (full) : 2026-03-22T16:30:00+00:00
VPN Status            : CONNECTED
```

VPN status is derived from the `wg0` interface and its peer endpoint.

### WireGuard & Connection Info

- `### ip addr show wg0` — tunnel interface address
- `### wg show` — peer public key, endpoint, last handshake, transfer counters, listening port
- `### wg0.conf` — the generated config (private key redacted in logs)

The peer endpoint reported by `wg show` is the VPN server you're connected to.

### System Network State

- `### ip link (up)` — link states
- `### ip route (main)` — main routing table
- `### ip rule` — policy routing rules (WireGuard installs an fwmark rule)
- `### ip route table 51820` — the WireGuard routing table (default via wg0)
- `### ip route get <test IP>` — which interface a packet to the internet uses (should be wg0)

### Firewall Rules

- `### iptables -S (filter)` and `### iptables -t nat -S` — IPv4 rules
- `### ip6tables -S` / nat — IPv6 rules (if available)
- Detects whether nft or legacy backend is in use

### Public IP & Geolocation

- `### Public IP / Geo (best-effort)` — JSON from an IP lookup service (IP, city, country, ISP/org). This is what confirms which exit node you're using.

### DNS

- `### DNS configuration` — contents of `/etc/resolv.conf`
- `### DNS servers geolocation` — geolocation lookup for each nameserver
- `### resolver identity via <ns>` — identity probe of the active resolver

### Connectivity Tests

- `### Ping checks` — IPv4/IPv6 reachability
- `### Short trace to <test IP>` — first hop should be the VPN
- `### Quick verdicts` — summary checks

## IP Resolution Fallback

The diagnostic tool uses a fallback to determine your public IP from more than one service, each with a short timeout, so a single slow/unreachable provider doesn't block the report.

## Using Diagnostics for Troubleshooting

| Symptom | What to check in diagnostic output |
|---------|------|
| Wrong country | Public IP / Geo — confirms which exit you're using |
| DNS leaks | DNS configuration / geolocation — nameservers should be VPN-provided |
| No connectivity | `wg show` — confirm a recent handshake and non-zero received bytes |
| Traffic not tunneled | `ip route get` — should resolve via `wg0` |
| Firewall issues | iptables dump — look for missing ACCEPT rules on wg0 |

See also: [Troubleshooting](Troubleshooting)
