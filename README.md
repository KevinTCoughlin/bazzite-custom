# bazzite-custom

Custom [Bazzite DX](https://bazzite.gg) image with layered packages baked in, so rebases (e.g. Fedora version upgrades) carry everything automatically.

## What's included

**Base:** `ghcr.io/ublue-os/bazzite-dx:stable`

**Added packages:**
- `gamemode` — on-demand game performance optimizer
- `kmail` — KDE email client
- `nextdns` — DNS-over-TLS/HTTPS client
- `tlp` — battery/power management
- `wezterm` — GPU-accelerated terminal

**Removed from base:**
- `code` — VS Code RPM (using Flatpak/Insiders instead)

## Usage

### Rebase to this image

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/kevintcoughlin/bazzite-custom:latest
systemctl reboot
```

### Revert to stock Bazzite

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable
systemctl reboot
```

## Development

### Prerequisites

- [Podman](https://podman.io/) (or Docker)
- A GitHub account with [GHCR access](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Clone

```bash
git clone https://github.com/KevinTCoughlin/bazzite-custom.git
cd bazzite-custom
```

### Build locally

```bash
podman build -t bazzite-custom .
```

### Push to GHCR manually

```bash
podman login ghcr.io
podman tag bazzite-custom ghcr.io/kevintcoughlin/bazzite-custom:latest
podman push ghcr.io/kevintcoughlin/bazzite-custom:latest
```

### Automated builds

A GitHub Actions workflow builds and pushes the image automatically:
- Weekly (Monday 9am UTC)
- On every push to `main`
- On manual dispatch

## Files

| File | Purpose |
|------|---------|
| `Containerfile` | Podman/Docker build definition |
| `recipe.yml` | [BlueBuild](https://blue-build.org/) declarative recipe (alternative to Containerfile) |
| `.github/workflows/build.yml` | CI pipeline for automated image builds |

## Customizing

Edit the `Containerfile` to add/remove packages, then push to trigger a rebuild:

```dockerfile
RUN rpm-ostree install <your-package> && rpm-ostree cleanup -m
```

Or edit `recipe.yml` if using BlueBuild.
