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

Multiple values are semicolon-separated: `COUNTRY="United States;CA;228"`

### Specific Server Hostname Format

To connect to a specific NordVPN server, use its short hostname. The format is:

```
<2-letter country code><server number>
```

**Pattern:** Exactly 2 letters followed by 1 or more digits (case-insensitive).

| Input | Resolved hostname | How it works |
|-------|------------------|---------------|
| `us1` | `us1.nordvpn.com` | US server #1 |
| `DE456` | `de456.nordvpn.com` | Germany server #456 |
| `gb42` | `gb42.nordvpn.com` | UK server #42 |

Specific servers are:
- Looked up by hostname against the NordVPN API for their WireGuard endpoint and public key
- Given `load=0` so they always appear first in the server list
- Placed in either `COUNTRY` or `CITY` — both work the same way

**Invalid formats** (will be treated as country/city names): `usa1` (3 letters), `u1` (1 letter), `us` (no digits).

Reference lists:
- [Countries](https://github.com/azinchen/nordvpn-wg/blob/main/COUNTRIES.md)
- [Cities](https://github.com/azinchen/nordvpn-wg/blob/main/CITIES.md)
- [Groups](https://github.com/azinchen/nordvpn-wg/blob/main/GROUPS.md)

## Selection Behavior

- **Specific servers** (e.g., `es1234`): Placed at the top of the list with `load=0`
- **Multiple locations**: Combined and sorted by server load (lowest first)
- **Single location**: Keeps NordVPN's recommended order
- **RANDOM_TOP=N**: After filtering and sorting, randomly picks from the top N servers

All server lookups are filtered to NordVPN's NordLynx (WireGuard) technology. Cities are
resolved to their NordVPN city ID and queried via the `country_city_id` API filter.
