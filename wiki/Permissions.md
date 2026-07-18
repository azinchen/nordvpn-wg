WireGuard's `wg-quick` needs root and specific kernel capabilities to create the tunnel interface and program routing/firewall rules. This container therefore runs its processes as **root** inside the container (there is no privilege-dropping process user, unlike the OpenVPN variant).

## Required Capabilities & Devices

| Requirement | Why |
|-------------|-----|
| `--cap-add=NET_ADMIN` | Create/configure the `wg0` interface, policy routing, and iptables rules |
| `--sysctl net.ipv4.conf.all.src_valid_mark=1` | Required for WireGuard's reverse-path / fwmark routing. `wg-quick` tries to set this itself but can't inside a container (read-only `/proc/sys`), so it must be passed in — otherwise the tunnel fails to come up. |

That's all that's needed. The image uses **kernel** WireGuard (it ships only `wireguard-tools`, no userspace backend), so:

- **`/dev/net/tun` is not required** — TUN is only used by userspace WireGuard implementations (wireguard-go/boringtun).
- **`SYS_ADMIN` is not required** — passing the sysctl above via Docker removes the only reason `wg-quick` would have needed it.

The trade-off is that the host kernel must provide WireGuard (5.6+ built in, or the `wireguard` module loaded) — there is no userspace fallback. If your host blocks sysctl changes entirely, `privileged: true` works as a last resort.

### Docker Compose

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
```

### Docker Run

```bash
docker run -d --cap-add=NET_ADMIN \
           --sysctl net.ipv4.conf.all.src_valid_mark=1 \
           -e TOKEN=your_nordvpn_token_here \
           azinchen/nordvpn-wg
```

## Volume Permissions

This container does not create a separate process user and does not take `PUID`/`PGID`.
Containers that share the VPN's network namespace manage their own volume permissions
independently.
