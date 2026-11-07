This image supports multiple CPU architectures. Docker will automatically pull the correct image for your platform.

## Available Architectures

The images on Docker Hub and GHCR are built for the platforms listed in the CI configuration (`PLATFORMS` in `ci-build-deploy.yml`; see [Building and CI](Building-and-CI)) — every platform that both Alpine Linux and s6-overlay provide, except `ppc64le`, `s390x` and `riscv64`:

| Architecture | Platform |
|--------------|----------|
| `386` | 32-bit x86 |
| `amd64` | 64-bit x86 |
| `arm/v6` | ARM v6 |
| `arm/v7` | ARM v7 (Raspberry Pi 2/3) |
| `arm64` | 64-bit ARM (Raspberry Pi 4/5, Apple M1) |

Three architectures were dropped from the published images: `riscv64` (published up to v2.4.0) because Alpine builds its riscv64 packages and the official `alpine` Docker image on slower hardware, so they land hours to days after the other architectures and repeatedly blocked the multi-arch build; `ppc64le` and `s390x` (published up to v2.5.0) because no demand for IBM Power or System z images was ever recorded, while every release still had to be built and scanned for them under QEMU emulation. The Dockerfile still supports all three, so you can build them locally:

```bash
docker buildx build --platform linux/ppc64le -t nordvpn-wg:ppc64le .
docker buildx build --platform linux/s390x -t nordvpn-wg:s390x .
docker buildx build --platform linux/riscv64 -t nordvpn-wg:riscv64 .
```

## Automatic Architecture Detection

When you run `docker pull azinchen/nordvpn-wg`, Docker automatically detects your system's architecture and pulls the appropriate image variant. No manual selection is required.

## Verifying Your Architecture

To check which architecture Docker is using:

```bash
docker image inspect azinchen/nordvpn-wg:latest --format '{{.Architecture}}'
```

## Raspberry Pi Notes

- **Raspberry Pi 2/3**: Uses `arm/v7`
- **Raspberry Pi 4/5**: Uses `arm64` (recommended) or `arm/v7`
- **Raspberry Pi Zero/1**: Uses `arm/v6`

For best performance on Raspberry Pi 4 and newer, ensure you're running a 64-bit OS to take advantage of the `arm64` image.
