The `GROUP` environment variable filters the NordVPN server fleet by specialty. Each group is a separate set of servers with different capabilities. Only **one** group can be set at a time.

> **NordLynx only:** this container connects with NordLynx (WireGuard). Server lookups are always filtered to NordLynx-capable servers. Groups that historically exist only for OpenVPN (e.g. **Obfuscated / XOR**) have no NordLynx servers — selecting them returns nothing and the container falls back to the recommended pool.

## Quick Reference

| Group | Identifier | Availability |
|-------|-----------|--------------|
| Standard VPN servers | `legacy_standard` | All countries |
| P2P | `legacy_p2p` | Most countries |
| Double VPN | `legacy_double_vpn` | Limited country pairs |
| Onion Over VPN | `legacy_onion_over_vpn` | Very limited (NL, SE, CH) |
| Dedicated IP | `legacy_dedicated_ip` | Subscription-dependent |
| Anti DDoS | `legacy_anti_ddos` | Limited |
| Europe | `europe` | Regional |
| The Americas | `the_americas` | Regional |
| Asia Pacific | `asia_pacific` | Regional |
| Africa, the Middle East and India | `africa_the_middle_east_and_india` | Regional |

You can also use the human-readable names (e.g., `GROUP=Double VPN`) or numeric IDs. The full list is in [GROUPS.md](https://github.com/azinchen/nordvpn-wg/blob/main/GROUPS.md).

When `GROUP` is not set, the API returns servers from the default recommended pool (equivalent to `legacy_standard`).

## Standard VPN Servers (`legacy_standard`)

The default NordVPN fleet. General-purpose servers suitable for everyday use.

```yaml
environment:
  # GROUP not needed — this is the default
  - COUNTRY=United States
```

Available in all countries and cities. This is what you get when `GROUP` is omitted.

## P2P (`legacy_p2p`)

Servers optimized for peer-to-peer traffic. These allow the incoming connections that BitTorrent and other P2P protocols require.

```yaml
environment:
  - GROUP=legacy_p2p
  - COUNTRY=Netherlands
```

Use when torrenting or file sharing. Available in most countries, though some countries where P2P is restricted by law may not have P2P servers.

## Double VPN (`legacy_double_vpn`)

Traffic is routed through two VPN servers in different countries. Availability of NordLynx Double VPN servers is limited — if none are returned, the container falls back to the recommended pool.

```yaml
environment:
  - GROUP=legacy_double_vpn
```

Server names show both countries (e.g., `ca-us75` = Canada entry → United States exit). You can filter by `COUNTRY` to select the exit country, but only pre-defined country pairs are available.

### Trade-offs

- Higher latency than standard servers (traffic traverses two hops)
- Lower throughput
- Not compatible with P2P traffic

## Onion Over VPN (`legacy_onion_over_vpn`)

The VPN server routes your outbound traffic into the Tor network. No local Tor client is needed. Available in very few locations (Netherlands, Sweden, Switzerland at time of writing).

```yaml
environment:
  - GROUP=legacy_onion_over_vpn
```

### Important: DNS configuration

**Do not override DNS** when using Onion Over VPN. The default NordVPN DNS servers (`103.86.96.100`, `103.86.99.100`) route DNS queries through the Tor network. If you set `DNS` to external resolvers (e.g., Cloudflare `1.1.1.1`), DNS queries will fail because Tor only carries TCP traffic and standard DNS uses UDP.

### Trade-offs

- Significantly slower than standard or Double VPN (Tor adds multiple hops)
- Not compatible with P2P traffic
- Some websites block Tor exit nodes

## Dedicated IP (`legacy_dedicated_ip`)

For NordVPN accounts with the [Dedicated IP add-on](https://nordvpn.com/features/dedicated-ip/). Provides a static IP address assigned exclusively to your account.

```yaml
environment:
  - GROUP=legacy_dedicated_ip
```

The API returns Dedicated IP servers regardless of your subscription status, but you need an active Dedicated IP add-on on your NordVPN account to successfully use these servers.

### When to use

- IP whitelisting for remote access
- Services that block shared VPN IP addresses
- When you need a consistent public IP

## Anti DDoS (`legacy_anti_ddos`)

Servers with DDoS protection.

```yaml
environment:
  - GROUP=legacy_anti_ddos
```

Useful for gaming or hosting services exposed through the VPN. This group may have limited server availability.

## Regional Groups

Broad geographic filters that return servers from an entire region rather than a specific country.

| Group | Identifier |
|-------|-----------|
| Europe | `europe` |
| The Americas | `the_americas` |
| Asia Pacific | `asia_pacific` |
| Africa, the Middle East and India | `africa_the_middle_east_and_india` |

```yaml
environment:
  - GROUP=europe
  - RANDOM_TOP=10
```

Use when you don't need a specific country — just a region.

## Combining with Other Parameters

`GROUP` is sent to the NordVPN API as an AND filter alongside other parameters. All filters must match for a server to be returned.

| Parameter | Combines with `GROUP`? | Notes |
|-----------|----------------------|-------|
| `COUNTRY` | Yes | Servers must match both group and country |
| `CITY` | Yes | Servers must match both group and city |
| `RANDOM_TOP` | Yes | Applied after filtering — picks randomly from top N results |

### Restrictions

- **One group at a time.** The API accepts a single group filter. You cannot combine `legacy_p2p` with `legacy_double_vpn`, for example.
- **NordLynx availability.** Groups without NordLynx servers (e.g. Obfuscated/XOR) return nothing.
- **Empty results.** If the combination of `GROUP` + `COUNTRY` + `CITY` has no matching servers, the container falls back to default recommended servers (without the group filter).

## Legacy and Internal Groups

The NordVPN API also lists groups that are **not useful** for this container:

| Group | Reason |
|-------|--------|
| `legacy_obfuscated_servers` | XOR obfuscation — OpenVPN only, no NordLynx servers |
| `legacy_ultra_fast_tv` (ID 5) | Legacy streaming group — few or no servers |
| `legacy_netflix_usa` (ID 13) | Legacy streaming group — few or no servers |
| `legacy_socks5_proxy` (ID 245) | SOCKS5 protocol — not supported by this container |
| `anycast-dns`, `geo_dns`, `grafana`, `kapacitor`, `fastnetmon` | NordVPN internal infrastructure |
