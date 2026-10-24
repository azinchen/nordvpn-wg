# NordVPN WireGuard Docker Container

[![GitHub release][github-release]][github-releases]
[![GitHub release date][github-releasedate]][github-releases]
[![GitHub build][github-build]][github-actions]<br>
[![GitHub stars][github-stars]][github-link]
[![GitHub forks][github-forks]][github-link]
[![Open issues][github-issues]][github-issues-link]
[![GitHub last commit][github-lastcommit]][github-link]<br>
[![Docker pulls][dockerhub-pulls]][dockerhub-link]
[![Docker stars][dockerhub-stars]][dockerhub-link]
[![Docker image size][dockerhub-size]][dockerhub-link]<br>
[![Multi-arch][multiarch-badge]][wiki-platforms]

WireGuard (NordLynx) client docker container that routes other containers' traffic through NordVPN servers automatically.

> **Prefer OpenVPN?** This has a sibling project, [**azinchen/nordvpn**](https://github.com/azinchen/nordvpn) — the same auto-routing NordVPN container over OpenVPN (including XOR traffic obfuscation). Both share the same configuration model and feature set.

## ✨ Key Features

- **🚀 Easy Setup** — Route any container's traffic through VPN with `--net=container:vpn`
- **⚡ NordLynx (WireGuard)** — Fast, modern tunnel to NordVPN's WireGuard servers
- **🔑 Access Token** — Pass `TOKEN` and the container fetches your WireGuard key itself ([details][wiki-token])
- **🌍 Server Selection** — Auto-select servers by country, city, group, or specific hostname ([details][wiki-server])
- **⚖️ Load Balancing** — Sorts by server load when multiple locations are given ([details][wiki-server-behavior])
- **🔄 Automatic Reconnection** — Periodic server switching and health monitoring ([details][wiki-reconnect])
- **🛡️ Kill Switch** — Default-deny firewall blocks all traffic when VPN is down ([details][wiki-security])
- **🏠 Local Network Access** — Allow specific CIDRs with `NETWORK=...` ([details][wiki-network])
- **🧭 Custom DNS** — Resolve through the tunnel; override with `DNS=...` ([details][wiki-dns])
- **📵 IPv6 Configuration** — Built-in chains default to DROP ([details][wiki-ipv6])
- **🧱 Firewall Backends** — Auto-selects nft or legacy backend, binds `wg-quick` to it ([details][wiki-firewall])
- **🧬 Userspace Fallback** — `wireguard-go` when the kernel lacks WireGuard ([details][wiki-userspace])
- **🚪 VPN Gateway Mode** — Route downstream subnets through the tunnel with `FORWARD_FROM` ([details][wiki-gateway])
- **🪜 TTL Tuning** — `TTL_SET` / `TTL_INC` hide cascade hops from client traceroutes ([details][wiki-ttl])
- **🩺 Docker Health Status** — Opt-in `HEALTHCHECK` reports tunnel state to Docker ([details][wiki-healthcheck])
- **🔎 Network Diagnostics** — Built-in network diagnostic tool and `status.json` status file ([details][wiki-diagnostics])

> **📖 [Full documentation on the Wiki][wiki-home]** — configuration guides, examples, troubleshooting, FAQ, and architecture.

---

## 🚀 Quick Start

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --sysctl net.ipv4.conf.all.src_valid_mark=1 \
           -e TOKEN=your_nordvpn_token_here \
           azinchen/nordvpn-wg
```

Route other containers through VPN:
```bash
docker run --net=container:vpn -d your/application
```

Also available from GitHub Container Registry: `ghcr.io/azinchen/nordvpn-wg`

### Getting a Token

1. Log into your [Nord Account Dashboard](https://my.nordaccount.com/)
2. Click **NordVPN** → **Manual setup** and complete verification
3. Generate a new **access token** and copy it
4. Pass it as `TOKEN` — the container reads your NordLynx (WireGuard) key from the NordVPN API on every connect

> **Note**: The token is different from your regular NordVPN login. It is used only to fetch your WireGuard key; the key lives only in the container-private WireGuard config (root-owned, mode 0600), is removed when the service stops, and is re-fetched on every connect — it is never logged and never stored in the image or a volume. See the [wiki][wiki-token] for the API one-liner if you prefer to inspect it yourself.

## 🐳 Docker Compose Example

```yaml
services:
  vpn:
    image: azinchen/nordvpn-wg:latest
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    environment:
      - TOKEN=your_nordvpn_token_here
      - COUNTRY=United States;CA
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=0 */6 * * *
      - NETWORK=192.168.1.0/24
    ports:
      - "8080:80"                  # host:container — use your app's listening port
    restart: unless-stopped

  app:
    image: nginx:alpine
    network_mode: "service:vpn"
    depends_on:
      - vpn
    restart: unless-stopped
```

> **More examples:** [Docker Compose][wiki-compose] · [Docker Run][wiki-run]

## ⚙️ Environment Variables

Grouped by feature; every variable is one line here — the linked wiki pages have the full descriptions. List values (countries, cities, CIDRs, URLs, IPs) accept `;` or `,` as separators; whitespace around separators is ignored.

### Credentials — [details][wiki-token]

| Variable | Default | Description |
|---|---|---|
| `TOKEN` | — (required) | NordVPN access token; your WireGuard key is fetched from the NordVPN API on every connect ([how to get one](#getting-a-token)). |

### Server selection — [details][wiki-server]

| Variable | Default | Description |
|---|---|---|
| `COUNTRY` | — | Countries to pick servers from: names, codes, IDs, or specific server hostnames ([list][nordvpn-countries]). |
| `CITY` | — | Cities: names, IDs, or specific server hostnames ([list][nordvpn-cities]). |
| `GROUP` | — | Server group, e.g. `legacy_p2p` or `legacy_double_vpn` ([list][nordvpn-groups], [details][wiki-groups]). |
| `RANDOM_TOP` | `0` | Shuffle the top N servers of the filtered pool before picking one. |

### DNS — [details][wiki-dns]

| Variable | Default | Description |
|---|---|---|
| `DNS` | `103.86.96.100;103.86.99.100` | Resolvers written to `resolv.conf` after the tunnel comes up; resolution goes through the tunnel. |

### Reconnection and health — [details][wiki-reconnect]

| Variable | Default | Description |
|---|---|---|
| `RECREATE_VPN_CRON` | _(disabled)_ | Cron schedule for switching to a new server, e.g. `0 */6 * * *`. |
| `CHECK_CONNECTION_CRON` | _(disabled)_ | Cron schedule for the connectivity check that reconnects on failure. |
| `CHECK_CONNECTION_URL` | `https://www.google.com` | URL(s) probed through the tunnel by the check and by the Docker `HEALTHCHECK`. |
| `CHECK_CONNECTION_ATTEMPTS` | `5` | Failed attempts before the check declares the tunnel dead and reconnects. |
| `CHECK_CONNECTION_ATTEMPT_INTERVAL` | `10` | Seconds between attempts. |
| `HEALTHCHECK_ENABLED` | `false` | `true` = the Docker `HEALTHCHECK` probes `wg0` and `CHECK_CONNECTION_URL` instead of always reporting healthy ([details][wiki-healthcheck]). |

### Local network access — [details][wiki-network]

| Variable | Default | Description |
|---|---|---|
| `NETWORK` | — | LAN / inter-container IPv4 CIDRs allowed to bypass the tunnel (routes + firewall), e.g. `192.168.1.0/24`. |

### Gateway mode — [details][wiki-gateway]

| Variable | Default | Description |
|---|---|---|
| `FORWARD_FROM` | — | Downstream IPv4 CIDRs allowed to route out through the tunnel; traffic must arrive already SNATed into these nets. |
| `GATEWAY_DNS` | `off` | Client DNS interception for `FORWARD_FROM` sources: `redirect` (the `DNS` resolvers, through the tunnel) \| `local` (co-located resolver) \| `forward` (`GATEWAY_DNS_SERVER`) \| `off` ([details][wiki-gateway-dns]). |
| `GATEWAY_DNS_SERVER` | — | External IPv4 resolver(s) for `GATEWAY_DNS=forward`, reached directly over the uplink, **not** through the tunnel; the first one answering a probe at startup is used. |
| `TTL_SET` | _(unset)_ | Rewrite the TTL of traffic leaving through the tunnel (`1`–`255`, e.g. `64`); hides every hop behind this container from client traceroutes ([details][wiki-ttl]). |
| `TTL_INC` | _(unset)_ | Add to the TTL of traffic arriving on `eth0` (`1`–`255`, e.g. `1`) so this container disappears from client traceroutes; needs `FORWARD_FROM` ([details][wiki-ttl]). |

### Diagnostics and advanced

| Variable | Default | Description |
|---|---|---|
| `NETWORK_DIAGNOSTIC_ENABLED` | `false` | Run the built-in network diagnostic after every connect ([details][wiki-diagnostics]). |
| `NORDVPNAPI_IP` | `104.16.208.203;104.19.159.190` | IPs used for all NordVPN API access (no DNS involved); each also gets a host route out `eth0` so the API stays reachable with the tunnel down. |
| `ALLOW_MISSING_IPTABLES_RULES` | `false` | Tolerate failures applying `wg-quick`'s anti-leak iptables rules on kernels lacking the netfilter modules (e.g. Synology DSM); the container's own kill switch stays active ([details][wiki-allow-missing]). |

## 📋 Runtime Requirements

- `--cap-add=NET_ADMIN` and `--sysctl net.ipv4.conf.all.src_valid_mark=1` (or `privileged: true`) — see [Permissions][wiki-permissions]
- a kernel with WireGuard support (5.6+ built in, or the `wireguard` module); without it the container falls back to userspace `wireguard-go`, which additionally needs `--device /dev/net/tun` and is slower ([details][wiki-userspace])
- a NordVPN **access token**, not your regular account login — see [Getting a Token](#getting-a-token)
- a kernel with iptables support; the nft or legacy backend is picked automatically ([details][wiki-firewall])
- for gateway mode: `net.ipv4.ip_forward=1` on this container and on the downstream one ([details][wiki-gateway])

## 🐛 Issues

If you have any problems with or questions about this image, please open a [GitHub issue][github-issues-link].

Check the **[Troubleshooting][wiki-troubleshoot]** and **[FAQ][wiki-faq]** wiki pages first. For how the container works under the hood, see **[Architecture and Internals][wiki-architecture]**.

## 📄 License

[AGPL-3.0](LICENSE)

<!-- Links: Docker Hub -->
[dockerhub-link]: https://hub.docker.com/r/azinchen/nordvpn-wg
[dockerhub-pulls]: https://img.shields.io/docker/pulls/azinchen/nordvpn-wg?logo=docker&logoColor=white
[dockerhub-size]: https://img.shields.io/docker/image-size/azinchen/nordvpn-wg/latest?logo=docker&logoColor=white
[dockerhub-stars]: https://img.shields.io/docker/stars/azinchen/nordvpn-wg?logo=docker&logoColor=white

<!-- Links: GitHub -->
[github-link]: https://github.com/azinchen/nordvpn-wg
[github-issues]: https://img.shields.io/github/issues/azinchen/nordvpn-wg?logo=github&logoColor=white
[github-issues-link]: https://github.com/azinchen/nordvpn-wg/issues
[github-releases]: https://github.com/azinchen/nordvpn-wg/releases
[github-actions]: https://github.com/azinchen/nordvpn-wg/actions
[github-stars]: https://img.shields.io/github/stars/azinchen/nordvpn-wg?style=flat-square&logo=github&logoColor=white
[github-forks]: https://img.shields.io/github/forks/azinchen/nordvpn-wg?style=flat-square&logo=github&logoColor=white
[github-release]: https://img.shields.io/github/v/release/azinchen/nordvpn-wg?logo=github&logoColor=white
[github-releasedate]: https://img.shields.io/github/release-date/azinchen/nordvpn-wg?logo=github&logoColor=white
[github-build]: https://img.shields.io/github/actions/workflow/status/azinchen/nordvpn-wg/ci-build-deploy.yml?branch=main&label=build&logo=github&logoColor=white
[github-lastcommit]: https://img.shields.io/github/last-commit/azinchen/nordvpn-wg?logo=github&logoColor=white
[multiarch-badge]: https://img.shields.io/badge/multi--arch-386%20%7C%20amd64%20%7C%20arm%2Fv6%20%7C%20arm%2Fv7%20%7C%20arm64%20%7C%20ppc64le%20%7C%20s390x%20%7C%20riscv64-blue?logo=docker&logoColor=white

<!-- Links: Reference lists -->
[nordvpn-cities]: https://github.com/azinchen/nordvpn-wg/wiki/Cities-List
[nordvpn-countries]: https://github.com/azinchen/nordvpn-wg/wiki/Countries-List
[nordvpn-groups]: https://github.com/azinchen/nordvpn-wg/wiki/Groups-List

<!-- Links: Wiki -->
[wiki-home]: https://github.com/azinchen/nordvpn-wg/wiki
[wiki-token]: https://github.com/azinchen/nordvpn-wg/wiki/FAQ#credentials
[wiki-server]: https://github.com/azinchen/nordvpn-wg/wiki/Server-Selection
[wiki-server-behavior]: https://github.com/azinchen/nordvpn-wg/wiki/Server-Selection#selection-behavior
[wiki-groups]: https://github.com/azinchen/nordvpn-wg/wiki/Server-Groups
[wiki-reconnect]: https://github.com/azinchen/nordvpn-wg/wiki/Automatic-Reconnection
[wiki-healthcheck]: https://github.com/azinchen/nordvpn-wg/wiki/Automatic-Reconnection#docker-health-status
[wiki-security]: https://github.com/azinchen/nordvpn-wg/wiki/Security-Model#traffic-control--kill-switch
[wiki-network]: https://github.com/azinchen/nordvpn-wg/wiki/Local-Network-Access
[wiki-dns]: https://github.com/azinchen/nordvpn-wg/wiki/Custom-DNS
[wiki-ipv6]: https://github.com/azinchen/nordvpn-wg/wiki/IPv6-Configuration
[wiki-firewall]: https://github.com/azinchen/nordvpn-wg/wiki/Firewall-Backends
[wiki-allow-missing]: https://github.com/azinchen/nordvpn-wg/wiki/Firewall-Backends#allow_missing_iptables_rules
[wiki-permissions]: https://github.com/azinchen/nordvpn-wg/wiki/Permissions
[wiki-userspace]: https://github.com/azinchen/nordvpn-wg/wiki/Permissions#userspace-fallback-wireguard-go
[wiki-gateway]: https://github.com/azinchen/nordvpn-wg/wiki/VPN-Gateway-Mode
[wiki-gateway-dns]: https://github.com/azinchen/nordvpn-wg/wiki/VPN-Gateway-Mode#client-dns-gateway_dns
[wiki-ttl]: https://github.com/azinchen/nordvpn-wg/wiki/VPN-Gateway-Mode#ttl-tuning-ttl_set--ttl_inc
[wiki-diagnostics]: https://github.com/azinchen/nordvpn-wg/wiki/Network-Diagnostics-Guide
[wiki-architecture]: https://github.com/azinchen/nordvpn-wg/wiki/Architecture-and-Internals
[wiki-compose]: https://github.com/azinchen/nordvpn-wg/wiki/Docker-Compose-Examples
[wiki-run]: https://github.com/azinchen/nordvpn-wg/wiki/Docker-Run-Examples
[wiki-troubleshoot]: https://github.com/azinchen/nordvpn-wg/wiki/Troubleshooting
[wiki-faq]: https://github.com/azinchen/nordvpn-wg/wiki/FAQ
[wiki-platforms]: https://github.com/azinchen/nordvpn-wg/wiki/Supported-Platforms
