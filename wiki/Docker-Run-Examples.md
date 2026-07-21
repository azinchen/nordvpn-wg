## Basic Example

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --sysctl net.ipv4.conf.all.src_valid_mark=1 \
           -e TOKEN=your_nordvpn_token_here \
           azinchen/nordvpn-wg

# Run application through VPN
docker run -d --name app --net=container:vpn nginx
```

## Advanced Example with Port Mapping

```bash
docker run -d --name vpn \
           --cap-add=NET_ADMIN \
           --sysctl net.ipv4.conf.all.src_valid_mark=1 \
           -p 8080:8080 \
           -p 9091:9091 \
           -e TOKEN=your_nordvpn_token_here \
           -e COUNTRY="Germany;NL;202" \
           -e CITY="Amsterdam;6076868;uk2567" \
           -e GROUP="Standard VPN servers" \
           -e RANDOM_TOP=3 \
           -e RECREATE_VPN_CRON="0 */6 * * *" \
           -e NETWORK=192.168.1.0/24 \
           azinchen/nordvpn-wg

# Applications using VPN (access via host ports)
docker run -d --name webapp --net=container:vpn \
           nginx:alpine

docker run -d --name api-service --net=container:vpn \
           -v ./app:/app -w /app \
           node:alpine npm start
```

## Key Points

- **`--cap-add=NET_ADMIN`** and **`--sysctl net.ipv4.conf.all.src_valid_mark=1`** are always required. `SYS_ADMIN` is never needed. `/dev/net/tun` is not needed with kernel WireGuard; add `--device /dev/net/tun` only on hosts without the WireGuard kernel module, where the container falls back to userspace `wireguard-go` — see [Permissions](Permissions).
- **Ports** must be published on the VPN container (`-p` on the `vpn` container), not on the application containers.
- Application containers connect via `--net=container:vpn`.
- For GitHub Container Registry, replace `azinchen/nordvpn-wg` with `ghcr.io/azinchen/nordvpn-wg`.
