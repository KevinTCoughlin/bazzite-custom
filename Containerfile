FROM ghcr.io/ublue-os/bazzite-dx:stable@sha256:ea250d03962fdbbfb8f86584e27edec856f282a059ff538221e83fc6dec4713f

ARG IMAGE_REVISION=unknown
ARG NEXTDNS_VERSION=1.47.3
ARG NEXTDNS_SHA256=557e0450c3e6aacb2c6fc62ad7b64f336a6adf0c5e3ea04d1952c13b54299098
# Optional exact WezTerm nightly pin, e.g. 20260815_143815_9c04f79f. The COPR
# nightly repository only keeps recent builds, so a pin ages out and must be
# refreshed; leave it empty to layer the newest published nightly.
ARG WEZTERM_VERSION=""

LABEL org.opencontainers.image.description="Personal Bazzite DX image with additional workstation packages" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.source="https://github.com/KevinTCoughlin/bazzite-custom" \
      org.opencontainers.image.title="bazzite-custom"

COPY repos/wezterm-nightly.repo /etc/yum.repos.d/wezterm-nightly.repo
COPY repos/keys/RPM-GPG-KEY-wezterm-nightly /etc/pki/rpm-gpg/RPM-GPG-KEY-wezterm-nightly
COPY systemd/nextdns.service /usr/lib/systemd/system/nextdns.service

# NextDNS ships unsigned RPMs and RPM 6 verifies every package by default.
# The download is pinned by SHA-256, so dnf5 skips the OpenPGP check for that
# one local file only. Repository packages still install with gpgcheck enabled.
# dnf5 is required here: the bootc base is not a libostree-booted host, so
# rpm-ostree override and install fail during the container build. This matches
# the Universal Blue image-template, which customizes images with dnf5.
RUN set -eu \
    && curl --fail --location --retry 3 \
      --output /nextdns.rpm \
      "https://github.com/nextdns/nextdns/releases/download/v${NEXTDNS_VERSION}/nextdns_${NEXTDNS_VERSION}_linux_amd64.rpm" \
    && test "$(sha256sum /nextdns.rpm)" = "${NEXTDNS_SHA256}  /nextdns.rpm" \
    && wezterm_packages="wezterm wezterm-common wezterm-gui wezterm-mux-server" \
    && if [ -n "${WEZTERM_VERSION}" ]; then \
         pinned_packages="" ; \
         for package in ${wezterm_packages}; do \
           pinned_packages="${pinned_packages} ${package}-${WEZTERM_VERSION}-0.x86_64" ; \
         done ; \
         wezterm_packages="${pinned_packages}" ; \
       fi \
    && dnf5 -y remove code \
    && dnf5 -y install --nogpgcheck /nextdns.rpm \
    && dnf5 -y install \
      gamemode \
      kmail \
      ${wezterm_packages} \
    && rpm -q wezterm wezterm-common wezterm-gui wezterm-mux-server \
    && rm --force /nextdns.rpm \
    && dnf5 clean all \
    && rm --force /var/log/dnf5.log /var/log/dnf5.log.*

RUN rm --force /etc/init.d/nextdns \
    && chmod 0644 \
      /etc/pki/rpm-gpg/RPM-GPG-KEY-wezterm-nightly \
      /etc/yum.repos.d/wezterm-nightly.repo \
      /usr/lib/systemd/system/nextdns.service

# Verify the final bootc image, matching the Universal Blue image-template.
RUN bootc container lint
