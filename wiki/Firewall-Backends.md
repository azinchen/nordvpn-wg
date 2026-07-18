This image ships **both** `iptables` (nft-backed) and `iptables-legacy` (xtables). At runtime, the entrypoint automatically selects a working backend.

## Selection Logic

| Preferred backend | Fallback |
|-------------------|----------|
| **nft** (`iptables`) | legacy (`iptables-legacy`) |

The entrypoint probes each backend by toggling a chain policy and prefers nft,
falling back to legacy only when nft isn't usable in the container's network
namespace.

## Log Output

When the nft backend is selected:
```
[ENTRYPOINT] Kernel: 6.8.0-xx
[ENTRYPOINT] Using IPv4 backend: iptables
```

When nft isn't usable and the legacy backend is selected:
```
[ENTRYPOINT] Kernel: 6.8.0-xx
[ENTRYPOINT] Using IPv4 backend: iptables-legacy
```

## Why This Matters

- Some hosts (especially NAS devices, VMs, or WSL) don't support nftables properly in a container namespace
- Docker Desktop on macOS/Windows uses a Linux VM whose kernel may behave differently
- Mixing nft and legacy rules in the same namespace causes unpredictable behavior — the entrypoint prevents this

No manual configuration is needed. The container handles backend selection automatically.
