[![logo](https://github.com/azinchen/nordvpn-wg/raw/main/NordVpn_logo.png)](https://www.nordvpn.com/)

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
- **⚡ NordLynx (WireGuard)** — Fast, modern tunnel using NordVPN's WireGuard implementation
- **🔑 Token-Based Setup** — Provide a NordVPN access token; the key is fetched automatically ([details][wiki-token])
- **🌍 Smart Server Selection** — Auto-select servers by country, city, group, or specific hostname ([details][wiki-server])
- **⚖️ Load Balancing** — Intelligent sorting by server load when multiple locations specified
- **🔄 Auto-Reconnection** — Periodic server switching and health monitoring ([details][wiki-reconnect])
- **🛡️ Kill Switch** — Default-deny firewall blocks all traffic when VPN is down ([details][wiki-security])
- **🏠 Local/LAN Access** — Allow specific CIDRs with `NETWORK=...` ([details][wiki-network])
- **🧭 Custom DNS** — Resolve through the tunnel; override with `DNS=...` ([details][wiki-dns])
- **📵 IPv6 Firewall** — Built-in chains default to DROP ([details][wiki-ipv6])
- **🧱 iptables Compatibility** — Auto-selects nft or legacy backend ([details][wiki-firewall])
- **🧬 Userspace Fallback** — Automatic `wireguard-go` fallback on kernels without the WireGuard module ([details][wiki-permissions])
- **🚪 VPN Gateway Mode** — Route downstream subnets through the tunnel with `FORWARD_FROM` ([details][wiki-gateway])

> **📖 [Full documentation on the Wiki][wiki-home]** — configuration guides, examples, troubleshooting, FAQ, and architecture.

---

## Quick Start

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

### Requirements

- Docker with `--cap-add=NET_ADMIN` and `--sysctl net.ipv4.conf.all.src_valid_mark=1` (or `privileged: true`)
- A Linux kernel with WireGuard support — 5.6+ (built in) or the `wireguard` module loaded on the host. On kernels **without** the module, the container automatically falls back to userspace WireGuard (`wireguard-go`); that fallback additionally requires `--device /dev/net/tun` (not needed when the kernel module is available) and is slower than kernel WireGuard.
- A **NordVPN access token** (not your regular account login)

### Getting a Token

1. Log into your [Nord Account Dashboard](https://my.nordaccount.com/)
2. Click **NordVPN** → **Manual setup** and complete verification
3. Generate a new **access token** and copy it
4. Pass it as `TOKEN` — the container reads your NordLynx (WireGuard) key from the NordVPN API on every connect

> **Note**: The token is different from your regular NordVPN login. It is used only to fetch your WireGuard key; the key is never written to disk. See the [wiki][wiki-token] for the API one-liner if you prefer to inspect it yourself.

## Docker Compose Example

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
      - "8080:8080"
    restart: unless-stopped

  app:
    image: nginx:alpine
    network_mode: "service:vpn"
    depends_on:
      - vpn
    restart: unless-stopped
```

> **More examples:** [Docker Compose][wiki-compose] · [Docker Run][wiki-run]

## Environment Variables

> **List values** (countries, cities, CIDRs, URLs, IPs) accept `;` or `,` as separators; whitespace around separators is ignored.

### Credentials

NordVPN **access token** — see [Getting a Token](#getting-a-token) above.

| Variable | Details |
|---|---|
| **TOKEN** | **Required** — NordVPN access token; used to fetch your WireGuard key from the API. |

### Server Selection

Pick which servers to connect to; filters combine to narrow the pool. See [Server Selection][wiki-server].

| Variable | Details |
|---|---|
| **COUNTRY** | Filter by countries: names, codes, IDs, or server hostnames ([list][nordvpn-countries]). |
| **CITY** | Filter by cities: names, IDs, or server hostnames ([list][nordvpn-cities]). |
| **GROUP** | Filter by server group ([list][nordvpn-groups]). |
| **RANDOM_TOP** | Randomize top N servers. Default: `0` |

### Tunnel & DNS

DNS resolution through the tunnel. See [Custom DNS][wiki-dns].

| Variable | Details |
|---|---|
| **DNS** | DNS servers written to `resolv.conf` (resolution goes through the tunnel). Default: `103.86.96.100;103.86.99.100` |

### Reconnection & Health Monitoring

Rotate servers on a schedule and verify the tunnel actually works. See [Automatic Reconnection][wiki-reconnect].

| Variable | Details |
|---|---|
| **RECREATE<wbr>_VPN<wbr>_CRON** | Server switching schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_CRON** | Health monitoring schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_URL** | URLs to test connectivity. Default: `https://www.google.com` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPTS** | Connection test retry count. Default: `5` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPT<wbr>_INTERVAL** | Seconds between retries. Default: `10` |
| **HEALTHCHECK<wbr>_ENABLED** | Enable the Docker `HEALTHCHECK` probe (checks `wg0` + connectivity via `CHECK_CONNECTION_URL`). When `false`, the container always reports healthy. Default: `false` |

### Local Network & VPN Gateway

Open the kill‑switch firewall for LAN access and downstream routing. See [Local Network Access][wiki-network] and [VPN Gateway Mode][wiki-gateway].

| Variable | Details |
|---|---|
| **NETWORK** | LAN/inter‑container CIDRs to allow. Default: none |
| **FORWARD<wbr>_FROM** | Downstream CIDRs allowed to route OUT through the tunnel (gateway mode). Traffic must arrive already SNATed into these nets. Default: none |
| **GATEWAY<wbr>_DNS** | DNS interception for `FORWARD_FROM` clients: `redirect` (DNAT port 53 to the VPN resolvers from `DNS`, through the tunnel), `local` (DNAT port 53 to this container, for a co‑located resolver such as AdGuard Home), `forward` (DNAT port 53 to `GATEWAY_DNS_SERVER`, reached directly over the uplink — **not** through the tunnel), `off`. Default: `off` |
| **GATEWAY<wbr>_DNS<wbr>_SERVER** | External IPv4 resolver(s) for `GATEWAY_DNS=forward` (e.g. an AdGuard Home on your LAN). With a list, the first resolver answering a DNS probe at startup is used. Default: none |

### Advanced

Low‑level settings; the defaults work for most setups.

| Variable | Details |
|---|---|
| **NORDVPNAPI<wbr>_IP** | API bootstrap IPs. Default: `104.16.208.203;104.19.159.190` |
| **NETWORK<wbr>_DIAGNOSTIC<wbr>_ENABLED** | Enable network diagnostics on connect. Default: `false` |
| **ALLOW<wbr>_MISSING<wbr>_IPTABLES<wbr>_RULES** | Tolerate failures applying wg-quick's anti-leak iptables rules — needed on hosts whose kernel lacks the required netfilter modules (e.g. Synology DSM), where the tunnel would otherwise be torn down. The container's own default-DROP kill switch stays active. See [Firewall Backends][wiki-firewall]. Default: `false` |

## Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue][github-issues-link] or [email][email-link].

Check the **[Troubleshooting][wiki-troubleshoot]** and **[FAQ][wiki-faq]** wiki pages first.

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
[wiki-reconnect]: https://github.com/azinchen/nordvpn-wg/wiki/Automatic-Reconnection
[wiki-security]: https://github.com/azinchen/nordvpn-wg/wiki/Security-Model#traffic-control--kill-switch
[wiki-network]: https://github.com/azinchen/nordvpn-wg/wiki/Local-Network-Access
[wiki-dns]: https://github.com/azinchen/nordvpn-wg/wiki/Custom-DNS
[wiki-ipv6]: https://github.com/azinchen/nordvpn-wg/wiki/IPv6-Configuration
[wiki-firewall]: https://github.com/azinchen/nordvpn-wg/wiki/Firewall-Backends
[wiki-permissions]: https://github.com/azinchen/nordvpn-wg/wiki/Permissions
[wiki-gateway]: https://github.com/azinchen/nordvpn-wg/wiki/VPN-Gateway-Mode
[wiki-compose]: https://github.com/azinchen/nordvpn-wg/wiki/Docker-Compose-Examples
[wiki-run]: https://github.com/azinchen/nordvpn-wg/wiki/Docker-Run-Examples
[wiki-troubleshoot]: https://github.com/azinchen/nordvpn-wg/wiki/Troubleshooting
[wiki-faq]: https://github.com/azinchen/nordvpn-wg/wiki/FAQ
[wiki-platforms]: https://github.com/azinchen/nordvpn-wg/wiki/Supported-Platforms

[email-link]: mailto:alexander@zinchenko.com
