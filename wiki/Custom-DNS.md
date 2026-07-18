By default, the container resolves names through NordVPN's own DNS servers (`103.86.96.100` and `103.86.99.100`), reached over the tunnel. These may apply regional filtering — for example, certain domains may be sinkholed when connected through some exit nodes.

Because the kill-switch firewall makes Docker's embedded resolver (`127.0.0.11`) unreachable, the container writes its own `/etc/resolv.conf` after the tunnel comes up. This page covers how to override the DNS servers it uses.

## Method 1: The `DNS` Variable (recommended)

Set `DNS` to one or more servers (semicolon- or comma-separated). The container writes them to `/etc/resolv.conf` on every connect:

```yaml
services:
  vpn:
    environment:
      - DNS=1.1.1.1,1.0.0.1
```

- Default (unset): `103.86.96.100;103.86.99.100` (NordVPN).
- The servers must be reachable through the tunnel (any public resolver is) or via a `NETWORK` CIDR.

## Method 2: Bind-Mount a Custom `resolv.conf`

Mount a custom `resolv.conf` read-only. The container's attempt to rewrite it is rejected by the read-only mount (logged as a harmless warning), so your file stays in place:

**1. Create a `resolv.conf` file:**

```
nameserver 1.1.1.1
nameserver 1.0.0.1
```

**2. Mount it in your compose file:**

```yaml
services:
  vpn:
    volumes:
      - ./resolv.conf:/etc/resolv.conf:ro
```

## Popular DNS Providers

| Provider | Primary | Secondary |
|----------|---------|-----------|
| Cloudflare | `1.1.1.1` | `1.0.0.1` |
| Google | `8.8.8.8` | `8.8.4.4` |
| Quad9 | `9.9.9.9` | `149.112.112.112` |
| OpenDNS | `208.67.222.222` | `208.67.220.220` |

## Why Not Docker `dns:`?

Docker's `dns:` option configures an internal resolver (`127.0.0.11`) that forwards to the specified servers. In VPN containers with strict firewall rules (kill switch), Docker's internal DNS resolver is flushed/unreachable, resulting in `connection refused` errors. Use one of the methods above instead.

## Verifying Your DNS Configuration

After the VPN connects, check which DNS servers are active:

```bash
docker exec vpn cat /etc/resolv.conf
```

Test resolution:

```bash
docker exec vpn nslookup example.com
```

Run the full network diagnostic to see DNS details:

```bash
docker exec vpn /usr/local/bin/network-diagnostic
```

The diagnostic output includes a **DNS configuration** section showing the active nameservers and their geolocation.
