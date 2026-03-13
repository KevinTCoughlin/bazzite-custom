# Alternative: plain Containerfile if you prefer podman build over BlueBuild
# Build: podman build -t bazzite-custom .
# Push:  podman push bazzite-custom ghcr.io/<user>/bazzite-custom:latest
# Rebase: rpm-ostree rebase ostree-image-signed:docker://ghcr.io/<user>/bazzite-custom:latest

FROM ghcr.io/ublue-os/bazzite-dx:stable

# Remove unwanted base packages
RUN rpm-ostree override remove code && \
    rpm-ostree cleanup -m

# Add third-party repos for packages not in Fedora
COPY repos/ /etc/yum.repos.d/

# Install layered packages
RUN rpm-ostree install \
    gamemode \
    kmail \
    nextdns \
    tlp \
    wezterm && \
    rpm-ostree cleanup -m

# Enable services
RUN systemctl enable tlp.service
