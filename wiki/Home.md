# NordVPN WireGuard Docker Container — Wiki

Welcome to the wiki for the **NordVPN WireGuard Docker Container**. This wiki provides detailed configuration guides, examples, and troubleshooting information beyond what's covered in the [README](https://github.com/azinchen/nordvpn-wg#readme).

> **Looking for OpenVPN?** This has a sibling project, [**azinchen/nordvpn**](https://github.com/azinchen/nordvpn) — the same auto-routing NordVPN container over OpenVPN (including XOR traffic obfuscation). See its [wiki](https://github.com/azinchen/nordvpn/wiki) for OpenVPN-specific guides.

## Getting Started

If you're new, start with the [README](https://github.com/azinchen/nordvpn-wg#readme) for a quick-start guide, then explore the pages below for advanced configuration.

## Pages

### Configuration
- **[Server Selection](Server-Selection)** — Filter by country, city, group, or specific server hostname
- **[Server Groups](Server-Groups)** — Specialty server groups: Double VPN, Onion Over VPN, P2P, dedicated IP, and regional filters
- **[IPv6 Configuration](IPv6-Configuration)** — Prevent IPv6 leaks with daemon, container, or host-level options
- **[Automatic Reconnection](Automatic-Reconnection)** — Scheduled reconnection, failure handling, and health monitoring
- **[Local Network Access](Local-Network-Access)** — Allow LAN and inter-container traffic through the firewall
- **[VPN Gateway Mode](VPN-Gateway-Mode)** — Route other containers' traffic out through the tunnel with `FORWARD_FROM`
- **[Custom DNS](Custom-DNS)** — Override NordVPN's DNS servers with custom ones (Cloudflare, Google, etc.)
- **[Permissions](Permissions)** — required capabilities, devices, and sysctls for WireGuard

### Security
- **[Security Model](Security-Model)** — Kill switch behavior, rule precedence, and network access control
- **[Firewall Backends](Firewall-Backends)** — How nftables vs iptables-legacy selection works at runtime

### Examples
- **[Docker Compose Examples](Docker-Compose-Examples)** — Simple, advanced, and web-proxy compose setups
- **[Docker Run Examples](Docker-Run-Examples)** — Basic and advanced `docker run` usage

### Operations
- **[Updating and Maintenance](Updating-and-Maintenance)** — How to update the VPN container and restart dependent services
- **[Troubleshooting](Troubleshooting)** — Common problems, diagnostic tools, and log reading tips
- **[Network Diagnostics Guide](Network-Diagnostics-Guide)** — Using the built-in diagnostic tool and interpreting output

### Reference
- **[FAQ](FAQ)** — Frequently asked questions
- **[Supported Platforms](Supported-Platforms)** — Available architectures and Raspberry Pi notes
- **[Architecture and Internals](Architecture-and-Internals)** — How the s6-overlay stages, scripts, and firewall work under the hood
