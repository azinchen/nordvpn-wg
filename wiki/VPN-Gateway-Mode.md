By default the container only routes **its own** traffic (and that of containers sharing its network namespace) through the VPN. **Gateway mode** lets the container act as a router for *other* containers that keep their own network namespace — for example a VPN server (ocserv, WireGuard, SoftEther…) whose clients should exit through NordVPN.

This is the opposite of [`NETWORK`](Local-Network-Access): `NETWORK` lets traffic **bypass** the tunnel to reach your LAN, while `FORWARD_FROM` lets downstream traffic **route out through** the tunnel.

## What `FORWARD_FROM` Does

When `FORWARD_FROM` is set, the `init-firewall` script, for each CIDR:

1. Adds `FORWARD -s <cidr> -o wg0 -j ACCEPT` — lets that subnet's traffic leave through the tunnel.
2. Adds the matching `wg0 → <cidr>` `ESTABLISHED,RELATED` return rule.

The existing `POSTROUTING -o wg0 -j MASQUERADE` rule then NATs the forwarded packets onto the tunnel, so no extra NAT is needed.

Only the **`FORWARD`** chain is opened — `INPUT`/`OUTPUT` stay locked by the kill switch, and the rules reference `wg0`. If the tunnel drops, they cannot match, so **downstream traffic is dropped rather than leaked**.

## Requirements

- **The usual gateway capabilities:** `--cap-add=NET_ADMIN` and `--sysctl net.ipv4.conf.all.src_valid_mark=1` (the standard requirements — see [Permissions](Permissions); `SYS_ADMIN` and `/dev/net/tun` are not needed).
- **Enable IPv4 forwarding** on the container: `--sysctl net.ipv4.ip_forward=1`.
- **Downstream traffic must arrive already SNATed** into one of the `FORWARD_FROM` CIDRs (i.e. masqueraded to the downstream container's address on the shared docker network). That way the gateway needs **no return route** to the downstream client subnet — replies come back to an address it already knows.

## Multiple Subnets

`FORWARD_FROM` is semicolon- or comma-separated, just like `NETWORK`:

```bash
-e FORWARD_FROM="172.28.0.0/24;10.30.0.0/24;192.168.50.0/24"
```

## Docker Compose Example: ocserv (OpenConnect) server

This routes an [ocserv](https://github.com/azinchen/ocserv-server) OpenConnect/AnyConnect server's clients out through NordVPN. The `azinchen/ocserv-server` image takes a **`VPN_GATEWAY`** variable, so it SNATs its own VPN clients into the shared docker network and policy-routes them to the gateway for you — no manual `ip route`/`ip rule` needed on the downstream container.

```yaml
networks:
  ocservnet:
    ipam:
      config:
        - subnet: 172.20.0.0/24

services:
  vpn:
    image: azinchen/nordvpn-wg:latest
    container_name: ocserv-nordvpn
    cap_add:
      - NET_ADMIN                            # only capability the gateway needs
    sysctls:
      - net.ipv4.ip_forward=1                # required: forward downstream traffic
      - net.ipv4.conf.all.src_valid_mark=1   # required by WireGuard
      - net.ipv6.conf.all.disable_ipv6=1     # optional: avoid IPv6 leaks
    environment:
      - TOKEN=your_nordvpn_token_here
      - CITY=New York
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=0 */3 * * *
      - FORWARD_FROM=172.20.0.0/24           # the docker net ocserv SNATs into
    networks:
      ocservnet:
        ipv4_address: 172.20.0.2             # static, so ocserv can route to it
    restart: unless-stopped

  ocserv:
    image: azinchen/ocserv-server:latest
    container_name: ocserv-server
    depends_on:
      - vpn
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun                         # ocserv is a userspace VPN server, so it DOES need TUN
    sysctls:
      - net.ipv4.ip_forward=1                # required on the downstream too
    ports:
      - "8443:443/tcp"                       # published normally on ocserv itself
    environment:
      - VPN_SUBNET=10.20.0.0/24              # address pool handed to OpenConnect clients
      - VPN_GATEWAY=172.20.0.2               # route those clients out via the nordvpn-wg gateway
      - IPV6_FORWARD=0
      - IPV6_NAT=0
    networks:
      ocservnet:
        ipv4_address: 172.20.0.3
    restart: unless-stopped
```

Flow: an OpenConnect client gets an address from `10.20.0.0/24` → `ocserv` masquerades it to its own `172.20.0.3` (inside the `FORWARD_FROM` net) and policy-routes it to `172.20.0.2` → `nordvpn-wg` forwards it out the tunnel and masquerades it onto `wg0`. Replies return the same way. The client's public IP is then the NordVPN exit, and if the tunnel drops the kill switch blocks the forwarded traffic too.

> **Both containers need `net.ipv4.ip_forward=1`** (set above via `sysctls`). The `nordvpn-wg` gateway also needs `net.ipv4.conf.all.src_valid_mark=1` like any WireGuard container.

## Downstream containers without a built-in gateway option

`azinchen/ocserv-server` handles routing via `VPN_GATEWAY`. For a generic downstream container that has no such option, route **only the client subnet** out through the gateway with a policy rule, keeping the container's default route on the docker bridge.

Do **not** simply point the downstream's **default route** at the gateway — it breaks the downstream's own published ports: an inbound connection is `DNAT`ed in, but its reply would follow the default route into the tunnel and exit with the wrong source IP, so the client drops it.

```sh
# on the downstream container; 172.20.0.2 = the nordvpn-wg gateway
ip route replace default via 172.20.0.2 table 100
ip rule add from 10.20.0.0/24 lookup 100 priority 1000
```

The routing decision happens before the downstream container's own SNAT, so the `from 10.20.0.0/24` match works; client traffic goes to the gateway, while the listener's replies and the container's own traffic stay on the bridge.

## Security Notes

- **Keep `FORWARD_FROM` as narrow as possible** — every listed CIDR may route out through the tunnel.
- Forwarding is gated on `wg0`, so the kill switch still applies: no tunnel, no forwarding.
- This does **not** open any inbound ports on the gateway; publish the downstream service's ports on the downstream container.
