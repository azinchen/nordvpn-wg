How the image is built, tested, published and released. Useful for contributors; nothing here is needed to run the container.

## Building locally

```bash
git clone https://github.com/azinchen/nordvpn-wg.git
cd nordvpn-wg
docker build -t nordvpn-wg:local .
```

The build needs network access: it downloads the s6-overlay release tarballs and Alpine packages. Build arguments:

| ARG | Default | Purpose |
|---|---|---|
| `IMAGE_VERSION` / `BUILD_DATE` | `N/A` | Baked into the OCI labels and the startup banner by CI |

Everything else is pinned in the Dockerfile and bumped by the maintenance workflow (below): the Alpine base (`FROM alpine:X.Y.Z` on every stage), the s6-overlay release (`ENV PACKAGEVERSION` in the s6 builder stage) and the exact APK versions of `wireguard-tools`, `wireguard-go` and the other runtime packages.

Multi-arch:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t nordvpn-wg:local .
```

The Dockerfile builds every platform that both Alpine and s6-overlay provide; see [Supported Platforms](Supported-Platforms) for the published list.

## Build stages

The Dockerfile is a three-stage build; only the last stage ends up in the image.

| Stage | What it does |
|---|---|
| `s6-builder` | Downloads the [s6-overlay](https://github.com/just-containers/s6-overlay) release tarballs for the target architecture (`TARGETARCH` / `TARGETVARIANT` are mapped to s6-overlay's names) and unpacks them |
| `rootfs-builder` | Copies `root/` into place, fixes permissions, minifies the JSON data files, substitutes `__IMAGE_VERSION__` / `__BUILD_DATE__` in the entrypoint banner and merges the s6-overlay files |
| final | `alpine:X.Y.Z` plus the pinned runtime packages — `wireguard-tools` (`wg`, `wg-quick`), `wireguard-go` for the userspace fallback, `iptables` + `iptables-legacy`, `curl`, `jq`, `bind-tools` — and the `HEALTHCHECK` instruction; receives the assembled rootfs |

## WireGuard: Alpine packages, kernel or userspace

Unlike the OpenVPN sibling, nothing is compiled: WireGuard lives in the host kernel (5.6+ built in, or the `wireguard` module), and the image only ships the userspace tools from Alpine. `wireguard-go` is included so `wg-quick` can fall back to a userspace tunnel on kernels without the module — see [Permissions](Permissions#userspace-fallback-wireguard-go). Both packages are pinned to exact versions and bumped by the APK job.

## Version pinning

Every APK package in the Dockerfile is pinned to an exact version, so builds are reproducible and upgrades are explicit, reviewable diffs. `scripts/update-apk-versions.sh` refreshes the pins from the Alpine package repositories (main first, then community), checking each package once and updating every build stage where it is pinned:

```bash
./scripts/update-apk-versions.sh Dockerfile
```

A stale pin breaks the build as soon as Alpine drops the old package version, which is why the APK bot PR is the first thing to merge when CI goes red on `main`.

## CI workflows

| Workflow | Trigger | What it does |
|---|---|---|
| `ci-build-deploy` | every push and PR | Build and push. Branches: amd64 only → GHCR, tagged with the branch name. `main`: full platform matrix → GHCR `:dev`. Release tags: full matrix → Docker Hub + GHCR, `:<version>` and `:latest`, then the Docker Hub description is refreshed from the README and the built image is scanned (`security-docker`) |
| `security-docker` | daily schedule, manual, called by CI | Trivy and Grype scans of the published image (or the just-built tag), results uploaded to the Security tab |
| `security-comprehensive` | push / PR to `main`, weekly | Super-Linter plus Trivy filesystem and Dockerfile/config scans, results uploaded to the Security tab |
| `maintenance-updates` | daily schedule, manual | Bot PRs, one per change: server lists in the wiki, `countries.json` / `groups.json`, the NordVPN API IPs, APK pin refresh, s6-overlay bump, Alpine base bump |
| `maintenance-cleanup` | weekly schedule, manual | Prunes old GHCR and Docker Hub tags with [container-registry-pruner](https://github.com/azinchen/container-registry-pruner): release tags older than a year, development tags older than 90 days, keeping the latest per minor version; dry-run by default when run manually |
| `wiki-publish` | tag push, manual | Mirrors the repository's `wiki/` folder into the GitHub wiki, so the published wiki always matches the latest release |

Dependabot keeps the GitHub Actions versions current with weekly PRs. Platform matrix for `main` and releases: `linux/386, linux/amd64, linux/arm/v6, linux/arm/v7, linux/arm64, linux/ppc64le, linux/s390x, linux/riscv64`.

### Bot PR labels

The maintenance workflow labels its PRs so release notes can be generated from them: `dependencies` for the APK, s6-overlay and Alpine bumps, `data` for the server-list and data-file refreshes. Dependabot PRs carry `dependencies`, `github-actions` and `automation`.

## Image tags

| Tag | Meaning |
|---|---|
| `latest` | Latest release (Docker Hub + GHCR) |
| `2.2.0` | A specific release — the git tag without its `v` prefix |
| `dev` | Current `main` branch, full platform matrix (GHCR only) |
| `<branch>` | Development branch build, amd64 only (GHCR only); `/` in the branch name becomes `-` |

## Releases

### Version scheme

Releases are tagged **`vX.Y.Z`** (semantic versioning; the Docker tag drops the `v`). Versioning is independent of the OpenVPN sibling. The minor version is bumped for new variables, behavior changes, base-image or WireGuard-tools upgrades and larger documentation work; the patch version for a release that only carries security or bug fixes.

### Cutting a release

1. Make sure `main` is green and the bot PRs you want included are merged.
2. Create the GitHub release for the new tag on `main` (`gh release create vX.Y.Z --target <sha> --title vX.Y.Z --notes-file notes.md`, or the web UI). Pushing the tag triggers CI: the full platform matrix is built and pushed as `:X.Y.Z` and `:latest` to Docker Hub and GHCR, the image is scanned, and the wiki is published.
3. Fill the release description using the format below.

### Release description format

The format lives at [`.github/RELEASE_TEMPLATE.md`](https://github.com/azinchen/nordvpn-wg/blob/main/.github/RELEASE_TEMPLATE.md). Structure:

- a one-or-two-sentence summary of why to upgrade — security updates lead with **"Security update — upgrading is recommended."**, and server-list changes name the added or removed locations;
- **📥 Pull this release** — the two `docker pull` lines and the multi-arch line;
- **⬆️ Upgrade notes** — required actions or behavior changes, or "No action required", with deep links into this wiki;
- **✨ Features / 🐛 Bug Fixes / ♻️ Refactoring / 📖 Documentation / 🌍 Data Updates / 📦 Package Updates / 🔧 CI/CD Updates** — hand-written, user-facing entries with PR references; package security bumps link their CVEs or advisories and say what the package does in this image;
- **🧩 Component versions** — wireguard-tools, wireguard-go, Alpine Linux, s6-overlay, read from the Dockerfile at the tag;
- **Contributors** and the **Full Changelog** compare link.

**Generate release notes** ([`.github/release.yml`](https://github.com/azinchen/nordvpn-wg/blob/main/.github/release.yml) categorizes merged PRs by label into the same section titles) can seed the section contents — rewrite the entries in user-facing wording rather than shipping raw PR titles.
