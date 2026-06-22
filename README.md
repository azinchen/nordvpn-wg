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
- **🚪 VPN Gateway Mode** — Route downstream networks out through the tunnel with `FORWARD_FROM=...` ([details][wiki-gateway])

> **📖 [Full documentation on the Wiki][wiki-home]** — configuration guides, examples, troubleshooting, FAQ, and architecture.

---

## Quick Start

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN --cap-add=SYS_ADMIN \
           --device /dev/net/tun \
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

- Docker with `--cap-add=NET_ADMIN`, `--cap-add=SYS_ADMIN`, `--device /dev/net/tun`, and `--sysctl net.ipv4.conf.all.src_valid_mark=1` (or `privileged: true`)
- A Linux kernel with WireGuard support (5.6+ built in, or the `wireguard` module)
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
      - SYS_ADMIN
    devices:
      - /dev/net/tun
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

| Variable | Details |
|---|---|
| **TOKEN** | **Required** — NordVPN access token; used to fetch your WireGuard key from the API. |
| **COUNTRY** | Filter by countries: names, codes, IDs, or server hostnames ([list][nordvpn-countries]). Semicolon‑separated. |
| **CITY** | Filter by cities: names, IDs, or server hostnames ([list][nordvpn-cities]). Semicolon‑separated. |
| **GROUP** | Filter by server group ([list][nordvpn-groups]). |
| **RANDOM_TOP** | Randomize top N servers. Default: `0` |
| **DNS** | DNS servers written to `resolv.conf` (resolution goes through the tunnel); semicolon‑ or comma‑separated. Default: `103.86.96.100;103.86.99.100` |
| **RECREATE<wbr>_VPN<wbr>_CRON** | Server switching schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_CRON** | Health monitoring schedule (cron). Default: disabled |
| **CHECK<wbr>_CONNECTION<wbr>_URL** | URLs to test connectivity; semicolon‑separated. Default: `https://www.google.com` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPTS** | Connection test retry count. Default: `5` |
| **CHECK<wbr>_CONNECTION<wbr>_ATTEMPT<wbr>_INTERVAL** | Seconds between retries. Default: `10` |
| **NETWORK** | LAN/inter‑container CIDRs to allow; semicolon‑separated. Default: none |
| **FORWARD<wbr>_FROM** | Downstream CIDRs allowed to route OUT through the tunnel (gateway mode). Traffic must arrive already SNATed into these nets. Semicolon‑ or comma‑separated. Default: none |
| **NORDVPNAPI<wbr>_IP** | API bootstrap IPs (semicolon‑separated). Default: `104.16.208.203;104.19.159.190` |
| **NETWORK<wbr>_DIAGNOSTIC<wbr>_ENABLED** | Enable network diagnostics on connect. Default: `false` |

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
[nordvpn-cities]: https://github.com/azinchen/nordvpn-wg/blob/main/CITIES.md
[nordvpn-countries]: https://github.com/azinchen/nordvpn-wg/blob/main/COUNTRIES.md
[nordvpn-groups]: https://github.com/azinchen/nordvpn-wg/blob/main/GROUPS.md

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
[wiki-gateway]: https://github.com/azinchen/nordvpn-wg/wiki/VPN-Gateway-Mode
[wiki-compose]: https://github.com/azinchen/nordvpn-wg/wiki/Docker-Compose-Examples
[wiki-run]: https://github.com/azinchen/nordvpn-wg/wiki/Docker-Run-Examples
[wiki-troubleshoot]: https://github.com/azinchen/nordvpn-wg/wiki/Troubleshooting
[wiki-faq]: https://github.com/azinchen/nordvpn-wg/wiki/FAQ
[wiki-platforms]: https://github.com/azinchen/nordvpn-wg/wiki/Supported-Platforms

[email-link]: mailto:alexander@zinchenko.com
