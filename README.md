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

## Architecture

The workstation is built in layers, each managed by a different tool:

| Layer | Tool | Repo / Source |
|-------|------|---------------|
| **OS packages** | rpm-ostree (this image) | `KevinTCoughlin/bazzite-custom` |
| **Dotfiles & shell config** | chezmoi | `KevinTCoughlin/dotfiles` |
| **CLI tools** | Homebrew (Linuxbrew) | Brewfile / manual |
| **Runtimes** | mise | `.tool-versions` / global config |
| **Desktop apps** | Flatpak | `flatpak list` |

This repo handles the OS layer. Everything else lives in the [dotfiles repo](https://github.com/KevinTCoughlin/dotfiles) or is installed via the steps below.

## Usage

### Rebase to this image

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/kevintcoughlin/bazzite-custom:latest
systemctl reboot
```

### Full workstation setup

After rebasing to the custom image on a fresh machine, complete the user-layer setup:

```bash
# 1. Install chezmoi and apply dotfiles
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply KevinTCoughlin

# 2. Install Homebrew (Linuxbrew)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 3. Install brew formulae
brew bundle --file=~/.Brewfile  # if chezmoi provides a Brewfile, or install manually

# 4. Install runtimes via mise
mise install

# 5. Install Flatpak apps
# Re-install from a saved list, or manually add what you need
# flatpak install flathub $(cat flatpak-apps.txt)

# 6. Reload systemd for any quadlet units or timers from dotfiles
systemctl --user daemon-reload
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
| `repos/` | Third-party RPM repo files (nextdns, wezterm) copied into the image |
| `recipe.yml` | [BlueBuild](https://blue-build.org/) declarative recipe (alternative to Containerfile) |
| `.github/workflows/build.yml` | CI pipeline for automated image builds |

## Customizing

Edit the `Containerfile` to add/remove packages, then push to trigger a rebuild:

```dockerfile
RUN rpm-ostree install <your-package> && rpm-ostree cleanup -m
```

Or edit `recipe.yml` if using BlueBuild.
