# bazzite-custom

Personal Bazzite DX image with OS packages layered into the image so they survive
rebases and Fedora upgrades.

## Contents

The image is based on `ghcr.io/ublue-os/bazzite-dx:stable` and adds `gamemode`,
`kmail`, `nextdns`, and `wezterm`. It removes the `code` RPM because VS Code is
managed separately. Bazzite's existing tuned power-management stack is retained;
TLP is intentionally not layered because it conflicts with `tuned-ppd`.

The `Containerfile` is the only image definition. User configuration, Homebrew
packages, runtimes, and Flatpaks remain outside this repository.

## Trust and update model

- The Bazzite base is pinned by digest. Dependabot proposes weekly digest updates.
- GitHub Actions are pinned to commit SHAs and updated by Dependabot.
- The unsigned NextDNS RPM is pinned by version and SHA-256.
- WezTerm comes from the upstream nightly COPR, whose signing key is vendored and
  checked by fingerprint. That repository only keeps recent builds, so the image
  layers the newest published nightly by default. Pass
  `--build-arg WEZTERM_VERSION=<build id>` to reproduce an earlier build while it
  is still published.
- A read-only CI job builds and tests pull requests without persisted checkout
  or registry credentials.
- A separate trusted job handles main, scheduled, and manual publishing. It
  publishes immutable `sha-<commit>-run-<run>-<attempt>` rollback tags plus the
  rolling UTC date and `latest` tags, then attaches provenance attestations.

Review base-image and NextDNS pin updates independently. A Fedora major base
update may require a matching WezTerm build before merging.

## Rebase

First record the current deployment so it is available for rollback:

```bash
rpm-ostree status
```

This repository does not configure an rpm-ostree container-signing policy.
Verify the GitHub provenance attestation, then rebase by immutable digest:

```bash
gh attestation verify \
  oci://ghcr.io/kevintcoughlin/bazzite-custom@sha256:<digest> \
  --repo KevinTCoughlin/bazzite-custom

sudo rpm-ostree rebase \
  ostree-unverified-registry:ghcr.io/kevintcoughlin/bazzite-custom@sha256:<digest>
sudo systemctl reboot
```

After reboot, keep the previous deployment until the new one is confirmed:

```bash
rpm-ostree status
```

To undo the pending or current deployment, use `sudo rpm-ostree rollback` and
reboot. To leave the custom image entirely:

```bash
sudo rpm-ostree rebase \
  ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable
sudo systemctl reboot
```

## Local development

Requirements: Podman, Bash, GnuPG, and ShellCheck.

```bash
./tests/validate.sh
shellcheck tests/validate.sh

source_date_epoch="$(git show -s --format=%ct HEAD)"
podman build \
  --pull=always \
  --timestamp "${source_date_epoch}" \
  --build-arg "IMAGE_REVISION=$(git rev-parse HEAD)" \
  --tag bazzite-custom .
```

Test the result without booting it:

```bash
podman run --rm --entrypoint /usr/bin/rpm bazzite-custom \
  -q gamemode kmail nextdns wezterm
```

Publishing is intentionally performed only by GitHub Actions.

### Configure NextDNS

The image supplies a systemd unit but deliberately does not bake a private
NextDNS profile ID into a public image. Configure it after deployment, then
enable the service:

```bash
sudo nextdns config set -profile <profile-id>
sudo systemctl enable --now nextdns.service
nextdns status
```

## Repository layout

| Path | Purpose |
|---|---|
| `Containerfile` | Canonical image definition and package pins |
| `repos/` | WezTerm repository configuration and reviewed signing key |
| `systemd/nextdns.service` | Deterministic NextDNS service integration |
| `tests/validate.sh` | Fast supply-chain and workflow policy checks |
| `.github/workflows/build.yml` | Build, test, publish, and attest workflow |
| `.github/dependabot.yml` | Automated base-image and Actions update proposals |
