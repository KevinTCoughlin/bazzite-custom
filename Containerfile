FROM ghcr.io/ublue-os/bazzite-dx:stable@sha256:7ee528f2dfead79d1b4bbe080141b4db3e414dff4db72999926fb2129753dc9a

ARG IMAGE_REVISION=unknown
ARG NEXTDNS_VERSION=1.47.3
ARG NEXTDNS_SHA256=557e0450c3e6aacb2c6fc62ad7b64f336a6adf0c5e3ea04d1952c13b54299098
ARG WEZTERM_VERSION=20260815_143815_9c04f79f

LABEL org.opencontainers.image.description="Personal Bazzite DX image with additional workstation packages" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.source="https://github.com/KevinTCoughlin/bazzite-custom" \
      org.opencontainers.image.title="bazzite-custom"

COPY repos/wezterm-nightly.repo /etc/yum.repos.d/wezterm-nightly.repo
COPY repos/keys/RPM-GPG-KEY-wezterm-nightly /etc/pki/rpm-gpg/RPM-GPG-KEY-wezterm-nightly
COPY systemd/nextdns.service /usr/lib/systemd/system/nextdns.service

RUN curl --fail --location --retry 3 \
      --output /nextdns.rpm \
      "https://repo.nextdns.io/rpm/nextdns_${NEXTDNS_VERSION}_x86_64.rpm" \
    && test "$(sha256sum /nextdns.rpm)" = "${NEXTDNS_SHA256}  /nextdns.rpm" \
    && rpm-ostree override remove code \
    && rpm-ostree install \
      /nextdns.rpm \
      gamemode \
      kmail \
      "wezterm-${WEZTERM_VERSION}-0.x86_64" \
      "wezterm-common-${WEZTERM_VERSION}-0.x86_64" \
      "wezterm-gui-${WEZTERM_VERSION}-0.x86_64" \
      "wezterm-mux-server-${WEZTERM_VERSION}-0.x86_64" \
    && rm --force /nextdns.rpm \
    && rpm-ostree cleanup -m

RUN rm --force /etc/init.d/nextdns \
    && chmod 0644 \
      /etc/pki/rpm-gpg/RPM-GPG-KEY-wezterm-nightly \
      /etc/yum.repos.d/wezterm-nightly.repo \
      /usr/lib/systemd/system/nextdns.service
