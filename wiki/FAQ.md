## Credentials

**Q: What credentials do I need?**
A NordVPN **access token**. Pass it as `TOKEN` and the container reads your account's NordLynx (WireGuard) private key from the NordVPN API. See [Getting a Token](https://github.com/azinchen/nordvpn-wg#getting-a-token).

**Q: Can I use my regular NordVPN email and password?**
No. You need an access token generated from your Nord Account: [Nord Account Dashboard](https://my.nordaccount.com/) → NordVPN → Manual setup → generate an access token.

**Q: Does the token expire? Is it stored?**
The token is read at connect time to fetch your WireGuard key from the API; the key itself is never written to disk and is re-fetched on every (re)connect. The WireGuard key is persistent on your account, but the access token has the expiry you chose when generating it — keep it valid (or update `TOKEN` and restart) so reconnects keep working.

## Features

**Q: Which protocol does this use?**
NordLynx (NordVPN's WireGuard implementation), exclusively. OpenVPN, IKEv2, SOCKS, and HTTP proxy are not supported — use the [OpenVPN variant](https://github.com/azinchen/nordvpn) if you need those.

**Q: Can I use port forwarding / access services from the internet?**
No. NordVPN does not support inbound port forwarding. You can only access services from your LAN by publishing ports on the VPN container and setting `NETWORK` to include your LAN CIDR.

**Q: How do I know which server I'm connected to?**
Check the container logs: `docker logs vpn | grep "Selected server"`. Or run the network diagnostic: `docker exec vpn /usr/local/bin/network-diagnostic --basic`.

**Q: Can I connect to a specific server?**
Yes. Use the server hostname in `COUNTRY` or `CITY`: `-e COUNTRY=es1234` or `-e CITY=uk2567`. Specific servers get priority with `load=0`.

## Networking

**Q: Why can't my app containers reach my LAN?**
Set `NETWORK` to include your LAN CIDR (e.g., `-e NETWORK=192.168.1.0/24`). Docker subnets and LAN ranges are not auto-allowed. See [Local Network Access](Local-Network-Access).

**Q: Why do I need to publish ports on the VPN container instead of the app container?**
Containers using `network_mode: "service:vpn"` share the VPN container's network namespace. They don't have their own network stack, so port publishing only works on the VPN container.

**Q: Can I route a whole downstream subnet through the tunnel?**
Yes — see [VPN Gateway Mode](VPN-Gateway-Mode) and the `FORWARD_FROM` variable.

**Q: Does IPv6 work?**
The container applies an IPv6 firewall (default DROP), but does not route IPv6 through the VPN. To prevent IPv6 leaks, disable it at the daemon or container level. See [IPv6 Configuration](IPv6-Configuration).

**Q: Why is my torrent client "stalled" even though the swarm has seeds?**
libtorrent-based clients (qBittorrent, etc.) bind their listen, announce and DHT sockets to the interfaces present at startup. If the client starts before `wg0` is up, those sockets land on `eth0`, where the kill switch blocks them — so the client never discovers peers. Bind the client to the tunnel interface (qBittorrent: Settings → Advanced → Network interface → `wg0`). See [Troubleshooting](Troubleshooting#torrent-client-stalled-despite-a-healthy-swarm).

## Operations

**Q: Why do my app containers lose network after VPN restarts?**
Containers sharing the VPN's network namespace reference the old namespace after a restart. You must restart them too. See [Updating and Maintenance](Updating-and-Maintenance#why-dependent-containers-must-restart).

**Q: How often should I reconnect?**
Every 4–8 hours is common. Use `RECREATE_VPN_CRON` for scheduled switching and `CHECK_CONNECTION_CRON` for health monitoring. See [Automatic Reconnection](Automatic-Reconnection).

**Q: What happens if the VPN drops?**
The kill switch blocks all traffic except `NETWORK` CIDRs and NordVPN API IPs. If health monitoring is configured, the container will automatically reconnect. See [Security Model](Security-Model#traffic-control--kill-switch).

## Compatibility

**Q: Does this work on Raspberry Pi?**
Yes. The image supports `arm/v6`, `arm/v7`, and `arm64`. Docker pulls the correct architecture automatically. WireGuard support requires a reasonably recent kernel (5.6+ has it built in; older kernels need the `wireguard` module).

**Q: Does this work on Synology / QNAP NAS?**
Generally yes, but some NAS devices have older kernels or limited iptables/WireGuard support. The container auto-detects nft vs legacy backends. Check logs for `[ENTRYPOINT] Using IPv4 backend:` to verify.

**Q: What's the difference between Docker Hub and GHCR images?**
They are identical. Use whichever registry is more convenient: `azinchen/nordvpn-wg` (Docker Hub) or `ghcr.io/azinchen/nordvpn-wg` (GitHub Container Registry).

## Logs & Messages

**Q: The log says `VPN connected successfully` but I have no internet. Why?**
"Connected" means the `wg0` interface came up. If `wg show wg0` reports `0 B received` and no recent handshake, the NordLynx handshake isn't completing — usually a transient server issue or rate-limiting. The scheduled/health reconnect will pick a new server; see [Troubleshooting](Troubleshooting).

**Q: DNS resolution fails inside the container. Why?**
Docker's embedded resolver (`127.0.0.11`) is unreachable once the kill-switch firewall is applied, so the container writes its own `/etc/resolv.conf` pointing at the VPN DNS servers. If you overrode `DNS` with a server that isn't reachable through the tunnel, resolution will fail. See [Custom DNS](Custom-DNS).

**Q: `CRITICAL: TOKEN is not set` — what's wrong?**
`TOKEN` is required. Provide a valid NordVPN access token. If you see `could not obtain WireGuard private key from NordVPN API`, the token is invalid or expired.
