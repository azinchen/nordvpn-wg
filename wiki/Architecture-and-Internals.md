This page describes how the container works internally. Useful for contributors, debugging, and understanding the boot sequence.

## Boot Sequence

The container uses [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision. Services start in a defined order:

```
entrypoint (container start)
  │
  ├─ init-firewall       Apply iptables rules (depends on entrypoint backend selection)
  ├─ init-setupcron      Configure cron jobs from RECREATE_VPN_CRON / CHECK_CONNECTION_CRON
  │
  ├─ svc-nordvpn         Main WireGuard service (long-running)
  └─ svc-cron            Cron daemon (long-running; starts only after svc-nordvpn is
                         launched, so cron can never fire a reconnect or health check
                         before the first connection attempt)
```

## Key Scripts

### `entrypoint` — Backend selection & default-deny

Location: `/usr/local/bin/entrypoint`

1. Tests nft and legacy iptables backends by toggling a chain policy (`DROP` ↔ `ACCEPT` on `OUTPUT`) and piping an empty ruleset through `iptables-restore -n`
2. If the preferred backend fails, tests the fallback (a policy-only probe is kept as a last resort)
3. Repoints the unprefixed names (`iptables`, `iptables-restore`, `iptables-save` and `ip6tables` counterparts) at the selected backend so `wg-quick` uses the same stack; with `ALLOW_MISSING_IPTABLES_RULES=true` the restore names become tolerant wrappers (see [Firewall Backends](Firewall-Backends))
4. If legacy is selected and nft tables already contain rules, flushes nft tables to avoid mixed stacks
5. Exports selected backends (`IPT`, `IP6T`) to `/run/xt/backend.env`
6. Sets `INPUT`, `OUTPUT`, `FORWARD` to `DROP` on both IPv4 and IPv6
7. Allows loopback traffic

Backend preference:

| Preferred backend | Fallback |
|-------------------|----------|
| **nft** (`iptables`) | legacy (`iptables-legacy`) |

The container prefers the nft backend and falls back to legacy only if nft
isn't usable in its network namespace (the probe in step 1 decides this).

### `backend-functions` — Shared utilities

Location: `/usr/local/bin/backend-functions`

Sourced by every script. Provides the environment-variable defaults (including `dns`, `network`, `forward_from`, `nordvpnapi_ip`) and:
- `run4()` / `run6()` — Execute iptables commands with logging (non-fatal, always return 0)
- `run4_check()` — Like `run4` but propagates the iptables exit status, for callers that branch on whether a rule was actually added
- `run4_critical()` / `run6_critical()` — Execute or sleep forever on failure
- `trim()` — Strips whitespace around tokens split from `;`/`,` lists
- `is_vpn_connected()` — Checks for the `wg0` interface
- `apply_wireguard_config()` — Shared bring-up: refreshes the `VPN-SERVER` pinhole for the endpoint in `wg0.conf`, swaps the interface with `wg-quick` down/up, and writes `/etc/resolv.conf` from `$dns`; used by both the service start path and `vpn-reconnect`
- `log()` / `log_error()` / `log_warning()` — Timestamped logging
- `parse_cron()` — Converts cron expressions to human-readable descriptions

### `vpn-config` — Key retrieval & server selection

Location: `/usr/local/bin/vpn-config`

1. Fetches your NordLynx (WireGuard) **private key** from the NordVPN API using `TOKEN`
   (`v1/users/services/credentials`), via pinned API IPs (no DNS). The key is not cached —
   it is re-fetched on every connect. The token is handed to `curl` through a short-lived
   0600 config file (`-K`), never on the command line.
2. Resolves COUNTRY/CITY/GROUP to numeric IDs using the JSON data files
3. Builds the NordVPN API query (always filtered to NordLynx, tech id 35); CITY uses the
   `country_city_id` filter
4. Fetches the server list using pinned API IPs (no DNS)
5. Detects specific server hostnames (`us1234`, `ca-us100`, `nl-onion6`, `socks-nl1`) and
   looks each up through the API by hostname — again via pinned IPs, no DNS — so the pool
   entry carries the server's real address, load, and WireGuard public key. Unknown or
   retired hostnames are skipped with a warning instead of aborting selection.
6. Sorts by load (multi-location) or keeps API order (single location). If the pool is
   empty, falls back to the recommended pool — first still honoring `GROUP` (with only
   `GROUP` set this is the primary query), then once more without the group filter if the
   group has no NordLynx servers.
7. Applies `RANDOM_TOP` if set
8. Writes the selected server's WireGuard config to `/etc/wireguard/wg0.conf` (private key,
   `Address`, `[Peer]` endpoint + public key, `AllowedIPs = 0.0.0.0/0`, `PersistentKeepalive = 25`),
   atomically via a temp file. With `--fail-fast` (used by `vpn-reconnect`) a fatal error
   exits non-zero instead of blocking forever, leaving the existing config untouched.
9. Publishes the selection as machine-readable JSON to `/run/xt/status.json`
   (best-effort — a write failure never breaks configuration)

### `svc-nordvpn/run` — WireGuard launcher

Location: `/etc/s6-overlay/s6-rc.d/svc-nordvpn/run`

1. Calls `vpn-config` to generate `wg0.conf`
2. Adds a temporary pinhole in the `VPN-SERVER` chain for the server IP (UDP/51820 on eth0)
3. Brings the tunnel up with `wg-quick up wg0` (kernel WireGuard when available; on kernels without the module `wg-quick` automatically launches userspace `wireguard-go`, which needs `/dev/net/tun` — see [Permissions](Permissions))
4. Writes `/etc/resolv.conf` from `$dns` (Docker's embedded resolver is unreachable behind
   the kill switch)
5. Waits for the connection (checks `wg0`, up to ~60 seconds)
6. Optionally runs network diagnostics (`NETWORK_DIAGNOSTIC_ENABLED`)
7. Blocks (`sleep infinity`) to keep the service alive

> The WireGuard config intentionally omits a `DNS =` line — `wg-quick`'s `resolvconf` step
> fails inside Docker, so DNS is managed directly (step 4) instead.

### `svc-nordvpn/finish` — Cleanup on disconnect

Brings `wg0` down and flushes the `VPN-SERVER` chain so a fresh connect starts clean.

### `vpn-healthcheck` — Connection monitoring

Location: `/usr/local/bin/vpn-healthcheck`

1. Sends HTTP requests to the configured URL(s)
2. Retries `CHECK_CONNECTION_ATTEMPTS` times with configurable interval
3. If all fail, calls `vpn-reconnect`

### `vpn-reconnect` — Prepare-then-swap reconnection

Location: `/usr/local/bin/vpn-reconnect`

1. Takes an atomic `mkdir` lock (`/run/xt/vpn-reconnect.lock`) so overlapping triggers —
   `RECREATE_VPN_CRON`, a health-check reconnect, a manual run — never race; a second
   invocation logs "Another reconnection (pid N) is already in progress" and exits, and a
   lock whose owner died mid-run is taken over
2. Runs `vpn-config --fail-fast` **while the current tunnel stays up** — the API calls and
   load sorting don't count as downtime, and a failed selection keeps the existing
   connection and config untouched
3. Applies the new config via `apply_wireguard_config`: refreshes the firewall pinhole and
   swaps the interface. The only downtime is the `wg-quick` down/up itself (~1–2 s)

### `network-diagnostic` — Debug tool

Location: `/usr/local/bin/network-diagnostic`

Two modes:
- `--basic`: Public IP + geolocation only
- `--full` (default): Complete diagnostics including interfaces, iptables rules, DNS, routes, WireGuard status, the active WireGuard engine (kernel vs userspace `wireguard-go`), and kernel version

## Data Files

Located in `/usr/local/share/nordvpn/data/`:

| File | Purpose |
|------|---------|
| `countries.json` | Country name/code/ID mappings |
| `groups.json` | Server group definitions |

> **Origin of these files:** They are generated from the NordVPN public API (`https://api.nordvpn.com/`), not maintained by hand, and are refreshed automatically by the [`maintenance-updates`](https://github.com/azinchen/nordvpn-wg/actions/workflows/maintenance-updates.yml) GitHub Actions workflow, which opens a pull request when NordVPN changes its API schema. **Do not edit them by hand** — manual changes are overwritten the next time the workflow runs.

## State Files

| Path | Purpose |
|------|---------|
| `/run/xt/backend.env` | Selected iptables backend (IPT, IP6T) |
| `/etc/wireguard/wg0.conf` | Current server's WireGuard config (private key, peer, endpoint) |
| `/run/xt/status.json` | Last selected server as JSON (name, hostname, ip, technology, country, city, load, selected_at) — world-readable, for monitoring, e.g. `docker exec vpn cat /run/xt/status.json` |

## Connection Status

WireGuard is a silent protocol with no management socket. Status comes from the engine
(kernel module, or the `wireguard-go` UAPI socket at `/var/run/wireguard/wg0.sock` when the
userspace fallback is active — `wg` handles both transparently):

- `wg show wg0` — peer endpoint, last handshake, transfer counters
- `is_vpn_connected()` checks only that the `wg0` link exists; a real connection also needs a
  recent handshake and non-zero `received` bytes

## Firewall Build Phases

### Phase 1 — Entrypoint (default-deny)

The `entrypoint` script runs first and:
- Selects the iptables backend (nft or legacy — see [Firewall Backends](Firewall-Backends))
- Sets `INPUT`, `OUTPUT`, and `FORWARD` policies to `DROP` on both IPv4 and IPv6
- Allows loopback traffic (required for inter-process communication)

At this point, **all network traffic is blocked**.

### Phase 2 — init-firewall (allow VPN + exceptions)

The `init-firewall` service then:
- Detects the Docker network (eth0 subnet and gateway)
- Enables connection tracking (ESTABLISHED/RELATED)
- Sets up MASQUERADE on the `wg0` (VPN) interface
- Creates a `VPN-SERVER` chain and jumps eth0 UDP/51820 to it
- Adds NordVPN API IP exceptions (TCP/443 only) from `NORDVPNAPI_IP`, and pins a host
  route for each API IP out `eth0` — `wg-quick`'s `suppress_prefixlength` rule lets these
  main-table routes win, so the API stays reachable even when the tunnel is dead and
  `vpn-reconnect` can always recover
- If `NETWORK` is set, adds static routes (a failure logs a warning naming the value) and
  bidirectional allow rules for those CIDRs
- If `FORWARD_FROM` is set, opens `FORWARD` for those CIDRs over `wg0` (see [VPN Gateway Mode](VPN-Gateway-Mode))
- If `GATEWAY_DNS` is enabled, installs the client-DNS interception NAT rules for the
  `FORWARD_FROM` sources: port-53 DNAT to the tunnel resolvers (`redirect`), to the
  container itself (`local`), or to `GATEWAY_DNS_SERVER` (`forward` — including the
  startup probe that picks the first candidate answering a DNS query, plus the hairpin
  MASQUERADE and pinned host route that keep the resolver reachable over the uplink)

### Phase 3 — svc-nordvpn (per-connection pinhole)

When connecting:
- The VPN server IP gets a temporary rule in the `VPN-SERVER` chain (UDP/51820 on eth0)
- When the connection drops, `svc-nordvpn/finish` flushes that chain

## Firewall Chain Structure

```
INPUT chain:  ACCEPT lo → ACCEPT ESTABLISHED,RELATED → [NETWORK CIDRs] → DROP
OUTPUT chain: ACCEPT lo → ACCEPT ESTABLISHED,RELATED → ACCEPT wg0 → VPN-SERVER (eth0 udp/51820) → [NORDVPNAPI IPs] → [NETWORK CIDRs] → DROP
FORWARD chain: ACCEPT ESTABLISHED,RELATED → [FORWARD_FROM CIDRs over wg0] → DROP

VPN-SERVER chain: [temporary rule for the current VPN server IP]

NAT/POSTROUTING: MASQUERADE on wg0
```
