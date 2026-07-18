WireGuard's `wg-quick` needs root and specific kernel capabilities to create the tunnel interface and program routing/firewall rules. This container therefore runs its processes as **root** inside the container (there is no privilege-dropping process user, unlike the OpenVPN variant).

## Required Capabilities & Devices

| Requirement | Why |
|-------------|-----|
| `--cap-add=NET_ADMIN` | Create/configure the `wg0` interface, policy routing, and iptables rules |
| `--sysctl net.ipv4.conf.all.src_valid_mark=1` | Required for WireGuard's reverse-path / fwmark routing. `wg-quick` tries to set this itself but can't inside a container (read-only `/proc/sys`), so it must be passed in — otherwise the tunnel fails to come up. |
| `--device /dev/net/tun` | **Only** for hosts whose kernel lacks the WireGuard module — enables the automatic userspace fallback (see below). Not needed with kernel WireGuard. |

The image prefers **kernel** WireGuard and uses it whenever the host provides it (5.6+ built in, or the `wireguard` module loaded):

- **`/dev/net/tun` is not required** on such hosts — TUN is only used by the userspace fallback.
- **`SYS_ADMIN` is not required** — passing the sysctl above via Docker removes the only reason `wg-quick` would have needed it.

If your host blocks sysctl changes entirely, `privileged: true` works as a last resort.

## Userspace Fallback (wireguard-go)

The image also ships `wireguard-go`. When the kernel can't create a native WireGuard interface, `wg-quick` automatically falls back to it — no configuration needed; the log shows `[!] Missing WireGuard kernel module. Falling back to slow userspace implementation.` The fallback:

- requires `--device /dev/net/tun` (compose: `devices: [/dev/net/tun]`) — without it, startup fails on module-less hosts
- creates `wg0` as a TUN device; routing, kill switch, and all container features work identically
- is slower and uses more CPU than kernel WireGuard — hosts with the kernel module always use the kernel path automatically
- runs unsupervised: if the process dies, `wg0` disappears — enable `CHECK_CONNECTION_CRON` health monitoring so the container reconnects automatically

Check which engine is active with `docker exec vpn network-diagnostic` (the `WireGuard Engine` line).

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
