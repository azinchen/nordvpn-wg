The container supports three reconnection mechanisms: scheduled switching, connection failure handling, and health monitoring.

## Scheduled Reconnection

Use `RECREATE_VPN_CRON` to periodically switch to a different server. This uses standard cron syntax.

```bash
# Reconnect every 6 hours at minute 0
-e RECREATE_VPN_CRON="0 */6 * * *"

# Reconnect daily at 3 AM
-e RECREATE_VPN_CRON="0 3 * * *"

# Reconnect every 4 hours
-e RECREATE_VPN_CRON="0 */4 * * *"
```

When triggered, the cron job stops the `svc-nordvpn` service, which causes it to restart automatically. On restart, `vpn-config` re-fetches the server list and selects a new server based on current load.

## Connection Failure Handling

WireGuard is a connectionless, "silent" protocol — there is no session that errors out when the path dies, so failures don't restart the service on their own. The generated config sets `PersistentKeepalive = 25` to keep NAT mappings alive, but detecting a dead tunnel relies on **health monitoring** (below): when probes fail, the `svc-nordvpn` service is restarted and `vpn-config` selects a new server.

If you want servers rotated even without failures, combine health monitoring with scheduled reconnection (`RECREATE_VPN_CRON`).

## Connection Health Monitoring

Use the `CHECK_CONNECTION_*` variables for active health probing:

```bash
-e CHECK_CONNECTION_CRON="*/5 * * * *"
-e CHECK_CONNECTION_URL="https://1.1.1.1;https://8.8.8.8"
-e CHECK_CONNECTION_ATTEMPTS=3
-e CHECK_CONNECTION_ATTEMPT_INTERVAL=10
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CHECK_CONNECTION_CRON` | Disabled | Cron schedule for health checks |
| `CHECK_CONNECTION_URL` | `https://www.google.com` | URLs to probe (semicolon-separated) |
| `CHECK_CONNECTION_ATTEMPTS` | `5` | Number of retry attempts |
| `CHECK_CONNECTION_ATTEMPT_INTERVAL` | `10` | Seconds between retries |

## Docker Health Status

The image ships a Docker [`HEALTHCHECK`](https://docs.docker.com/reference/dockerfile/#healthcheck) that reports the container's health (`healthy` / `unhealthy`) to Docker, Compose `depends_on: condition: service_healthy`, Swarm/Kubernetes, and monitoring or autoheal sidecars. It is **observational only** — it never reconnects. Active recovery is handled separately by `CHECK_CONNECTION_*` and `RECREATE_VPN_CRON`.

It is **opt-in**: while disabled (the default) the probe always reports healthy without testing anything. Set `HEALTHCHECK_ENABLED=true` to activate it.

```bash
-e HEALTHCHECK_ENABLED=true
```

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTHCHECK_ENABLED` | `false` | Enable the Docker `HEALTHCHECK` probe. When disabled, the container always reports healthy. |

When enabled, the probe checks that the `wg0` interface exists and that a single short request to `CHECK_CONNECTION_URL` succeeds. The probe runs every 60s with a 60s start period and 3 retries before the container is marked `unhealthy`; unlike the cron `CHECK_CONNECTION_*` check it performs no retry loop of its own and never triggers a reconnect.

## Recommended Setup

For most users, combining scheduled reconnection with health monitoring provides robust connectivity:

```yaml
environment:
  - RECREATE_VPN_CRON=0 */6 * * *           # Switch server every 6 hours
  - CHECK_CONNECTION_CRON=*/5 * * * *       # Check every 5 minutes
  - CHECK_CONNECTION_URL=https://1.1.1.1    # Fast, reliable endpoint
  - CHECK_CONNECTION_ATTEMPTS=3
```
