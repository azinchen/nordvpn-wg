<!--
Release description format for nordvpn-wg.

Versioning: releases are tagged vX.Y.Z (semver, "v" prefix on the git tag),
independently of the OpenVPN sibling. The Docker image tags have no "v"
prefix: azinchen/nordvpn-wg:X.Y.Z. Bump the minor version for new variables,
behavior changes, base-image or WireGuard-tools upgrades and larger
documentation work; the patch version for a release that only carries
security or bug fixes.

Usage: create the GitHub release for the tag, copy this template into the
description and fill it in. "Generate release notes" (.github/release.yml)
can be used to seed the categorized sections with the merged PR list -
rewrite the entries in user-facing wording, as in past releases. Delete any
section that has no content. The release process is documented in the wiki
(Building and CI page).

The release.yml categories use the same section titles as this template.
Two have no section of their own: "Security" items go under Package Updates
(or Bug Fixes) and make the summary lead with the security sentence;
"Breaking changes" are described in Upgrade notes.
-->

One or two sentences: what this release is about and why to upgrade.
Security updates lead with **Security update — upgrading is recommended.**
When the server lists change, name the added/removed/re-marked locations here.

### 📥 Pull this release

```bash
docker pull azinchen/nordvpn-wg:X.Y.Z
docker pull ghcr.io/azinchen/nordvpn-wg:X.Y.Z
```

Multi-arch: `386`, `amd64`, `arm/v6`, `arm/v7`, `arm64`, `ppc64le`, `s390x`, `riscv64`. `latest` follows this release.

### ⬆️ Upgrade notes

<!-- Only when action is required or behavior changes: renamed/removed
variables, changed defaults, new variables that are off unless set.
Otherwise: "No action required — no variables, defaults or behavior
changed." Deep-link the wiki page for anything new. -->

### ✨ Features

<!-- One entry per feature, naming the variable, what it does and how it
fails, ending with a wiki link, e.g.:
- `TTL_SET` rewrites the TTL of all traffic leaving through `wg0` ... ; a value outside `1`–`255` stops the container at startup. See [VPN Gateway Mode — TTL Tuning](https://github.com/azinchen/nordvpn-wg/wiki/VPN-Gateway-Mode#ttl-tuning-ttl_set--ttl_inc) (#PR)
-->

- ... (#PR)

### 🐛 Bug Fixes

- ... (#PR)

### ♻️ Refactoring

- ... (#PR)

### 📖 Documentation

- ... (#PR)

### 🌍 Data Updates

<!-- Server-list and data-file changes from the maintenance workflow. Say
WHAT changed - inspect the wiki/Countries-List.md and wiki/Cities-List.md
diffs and name the locations; never a bare "Updated the lists". -->

#### ✅ Added Countries (N)

- Country (`CC`) — physical / virtual location (#PR)

#### ✅ Added Cities (N)

- City, Country — physical / virtual location (#PR)

#### 📝 Data File Updates

- `countries.json` ... ; the Countries list now has N countries and the Cities list N cities (#PR)

### 📦 Package Updates

<!-- Alpine / s6-overlay / APK pin bumps (wireguard-tools, wireguard-go,
curl, iptables, jq, bind-tools, ...), one line per package with the version
bump. Security bumps say so, link the upstream advisory or changelog, and
say what the package does in this image. Verify every intermediate version
when a bump spans several, e.g.:
- Bump Alpine 3.24.2 → 3.24.3. **Security:** the [3.24.3 announcement](https://alpinelinux.org/posts/...) covers ... (#PR)
- Bump wireguard-tools 1.0.20250521-r0 → 1.0.20260223-r0 ([upstream changelog](https://git.zx2c4.com/wireguard-tools/log/)) (#PR)
- Bump bind-tools 9.20.29-r0 → 9.20.30-r0. **Security:** [BIND 9.20.30](https://downloads.isc.org/isc/bind9/9.20.30/doc/arm/html/notes.html) fixes four CVEs, all in the `named` server; this image ships only the client tools (#PR)
- Bump curl 8.21.0-r0 → 8.22.0-r0 (#PR)
-->

### 🔧 CI/CD Updates

<!-- Workflow changes and GitHub Actions bumps, one line per action,
collapsing the Dependabot PRs for the same action into one entry, e.g.:
- Bump github/codeql-action 4.38.2 → 4.39.0 (#PR, #PR)
-->

### 🧩 Component versions

<!-- From the Dockerfile at the tag: the wireguard-tools= and wireguard-go=
apk pins, FROM alpine:X.Y.Z, s6-builder ENV PACKAGEVERSION. -->

| Component | Version |
|-----------|---------|
| wireguard-tools | 1.0.YYYYMMDD |
| wireguard-go | 0.0.YYYYMMDD |
| Alpine Linux | X.Y.Z |
| s6-overlay | D.E.F.G |

### Contributors

<!-- Add @dependabot[bot] when the release includes its PRs. -->

@azinchen

**Full Changelog**: https://github.com/azinchen/nordvpn-wg/compare/vPREV...vX.Y.Z
