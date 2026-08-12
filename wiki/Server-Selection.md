Filter NordVPN servers using location and server criteria.

## Example

```bash
docker run -d --cap-add=NET_ADMIN \
           --sysctl net.ipv4.conf.all.src_valid_mark=1 \
           -e TOKEN=your_nordvpn_token_here \
           -e COUNTRY="United States;CA;153" \
           -e CITY="New York;2619989;es1234" \
           -e GROUP="Standard VPN servers" \
           -e RANDOM_TOP=5 \
           azinchen/nordvpn-wg
```

## Location Specification

| Filter | Accepted formats | Examples |
|--------|-----------------|----------|
| **COUNTRY** | Name, 2-letter code, or numeric ID | `United States`, `US`, `228` |
| **CITY** | Name or numeric ID | `New York`, `8971718` |
| **Specific server** | Hostname (in COUNTRY or CITY) | `es1234`, `uk2567` |

Multiple values are separated by `;` or `,` (whitespace around separators is ignored): `COUNTRY="United States;CA;228"`

### Specific Server Hostname Format

To connect to a specific NordVPN server, use its short hostname. Four patterns are recognized (case-insensitive):

| Pattern | Example | Resolved hostname | Server kind |
|---------|---------|-------------------|-------------|
| `<cc><num>` | `us1`, `DE456` | `us1.nordvpn.com` | Standard server |
| `<cc>-<cc><num>` | `ca-us100`, `uk-fr17` | `ca-us100.nordvpn.com` | Cross-country (Double VPN) |
| `<cc>-onion<num>` | `nl-onion6` | `nl-onion6.nordvpn.com` | Onion Over VPN |
| `socks-<cc><num>` | `socks-nl1` | `socks-nl1.nordvpn.com` | SOCKS proxy host |

(`<cc>` = 2-letter country code, `<num>` = one or more digits.)

Specific servers are:
- Looked up through the NordVPN API by hostname — via the pinned API IPs, never DNS — to obtain their real address, load, and WireGuard public key
- Added to the pool alongside any other filter results; to guarantee connecting to one, list it as the only value
- Skipped with a warning (selection continues with the remaining values) if the hostname is unknown or retired
- Placed in either `COUNTRY` or `CITY` — both work the same way

> Only servers with NordLynx (WireGuard) support are usable — a SOCKS/onion host without a WireGuard key cannot be connected to by this image.

**Invalid formats** (will be treated as country/city names): `usa1` (3-letter prefix), `u1` (1 letter), `us` (no digits).

Reference lists:
- [Countries](Countries-List)
- [Cities](Cities-List)
- [Groups](Groups-List)

## Selection Behavior

- **Specific servers** (e.g., `es1234`): Join the pool with their real API data; list one alone to force its selection
- **Multiple locations**: Combined and sorted by server load (lowest first)
- **Single location**: Keeps NordVPN's recommended order
- **RANDOM_TOP=N**: After filtering and sorting, randomly picks from the top N servers

All server lookups are filtered to NordVPN's NordLynx (WireGuard) technology. Cities are
resolved to their NordVPN city ID and queried via the `country_city_id` API filter.
