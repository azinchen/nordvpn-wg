This image ships **both** `iptables` (nft-backed) and `iptables-legacy` (xtables). At runtime, the entrypoint automatically selects a working backend and binds the whole container to it.

## Selection Logic

| Preferred backend | Fallback |
|-------------------|----------|
| **nft** (`iptables`) | legacy (`iptables-legacy`) |

The entrypoint probes each backend in the container's network namespace:

1. **Policy probe** — toggle a chain policy (DROP, then revert).
2. **Restore probe** — pipe an empty ruleset through `iptables-restore -n`. This matters because `wg-quick` applies its anti-leak rules via `iptables-restore`, which exercises kernel paths the policy probe does not (e.g. the nftables generation-id fetch). Some kernels with partial nftables support — notably Synology DSM — pass the policy probe but fail restore.

The first backend passing both probes wins (nft preferred). If neither passes the restore probe, selection falls back to the policy probe alone.

## Backend Binding

After selection, the entrypoint repoints the unprefixed command names (`iptables`, `iptables-restore`, `iptables-save` and their `ip6tables` counterparts) at the selected backend. Alpine points these names at the nft backend unconditionally, and `wg-quick` calls `iptables-restore` by name — without the binding, a host where legacy was selected would still have `wg-quick` use nft, fail, and tear the tunnel down during startup.

## Log Output

When the nft backend is selected:
```
[ENTRYPOINT] Kernel: 6.8.0-xx
[ENTRYPOINT] Using iptables backend: iptables
```

When nft isn't usable and the legacy backend is selected:
```
[ENTRYPOINT] Kernel: 6.8.0-xx
[ENTRYPOINT] Using iptables backend: iptables-legacy
```

## ALLOW_MISSING_IPTABLES_RULES

Some NAS kernels (e.g. Synology DSM 4.4.x) cannot load the netfilter modules behind `wg-quick`'s anti-leak rules with **either** backend — typically `iptable_raw` and the `comment`/`addrtype`/`CONNMARK` extensions. On such hosts `iptables-restore` fails no matter what, `wg-quick` treats that as fatal, and the tunnel is rolled back:

```
[#] iptables-restore -n
iptables-restore v1.8.13 (nf_tables): Could not fetch rule set generation id: Invalid argument
[#] ip link delete dev wg0
...
[SERVICE-NORDVPN] VPN connection timeout
```

Setting `ALLOW_MISSING_IPTABLES_RULES=true` makes restore failures non-fatal: a warning is logged and startup continues without those rules. This is fail-closed by default because the skipped rules are protective; enable it only if your host cannot support them.

**What you lose:** `wg-quick`'s raw-table rule (drops packets addressed to the tunnel IP arriving outside the tunnel) and its mangle CONNMARK rules. **What you keep:** the container's own kill switch — default-DROP policies plus explicit allow rules — which remains the primary leak protection in this image.

## Why This Matters

- Some hosts (especially NAS devices, VMs, or WSL) don't support nftables properly in a container namespace
- Docker Desktop on macOS/Windows uses a Linux VM whose kernel may behave differently
- Mixing nft and legacy rules in the same namespace causes unpredictable behavior — the entrypoint prevents this

No manual configuration is needed for backend selection. `ALLOW_MISSING_IPTABLES_RULES` is the only opt-in, for kernels that cannot support `wg-quick`'s rules at all.
