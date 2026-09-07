#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

fail() {
  echo "validation failed: $*" >&2
  exit 1
}

grep -Eq '^FROM ghcr\.io/ublue-os/bazzite-dx:stable@sha256:[0-9a-f]{64}$' Containerfile \
  || fail "the base image must be pinned by digest"

grep -Eq '^ARG NEXTDNS_SHA256=[0-9a-f]{64}$' Containerfile \
  || fail "the unsigned NextDNS RPM must have a pinned checksum"

grep -Eq '^ARG WEZTERM_VERSION="([0-9]{8}_[0-9]{6}_[0-9a-f]+)?"$' Containerfile \
  || fail "the WezTerm pin must be empty or an exact nightly build identifier"

grep -Fq 'wezterm_packages="wezterm wezterm-common wezterm-gui wezterm-mux-server"' \
  Containerfile \
  || fail "the WezTerm subpackages must be layered as one consistent set"

grep -Fq 'skip_if_unavailable=False' repos/wezterm-nightly.repo \
  || fail "the WezTerm repository must fail closed"
grep -Fq 'gpgcheck=1' repos/wezterm-nightly.repo \
  || fail "WezTerm RPM signature checking must remain enabled"
grep -Fq 'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-wezterm-nightly' repos/wezterm-nightly.repo \
  || fail "the WezTerm key must be vendored"

fingerprint="$(
  gpg --show-keys --with-colons repos/keys/RPM-GPG-KEY-wezterm-nightly 2>/dev/null \
    | awk -F: '$1 == "fpr" { print $10; exit }'
)"
[[ "${fingerprint}" == "FD909B6288A84250AD58020FA69891C5CEA2757D" ]] \
  || fail "the vendored WezTerm key fingerprint changed"

if grep -REn 'uses:[[:space:]]+[^[:space:]]+@(v[0-9]+|main|master)([[:space:]#]|$)' .github/workflows; then
  fail "GitHub Actions must be pinned to immutable commit SHAs"
fi

grep -Fq 'pull_request:' .github/workflows/build.yml \
  || fail "pull requests must build and test the image"
grep -Fq 'actions/attest-build-provenance@' .github/workflows/build.yml \
  || fail "published images must receive provenance attestations"

validate_job="$(sed -n '/^  validate:/,/^  publish:/p' .github/workflows/build.yml)"
publish_job="$(sed -n '/^  publish:/,$p' .github/workflows/build.yml)"

grep -Fq "if: github.event_name == 'pull_request'" <<< "${validate_job}" \
  || fail "the read-only validation job must be limited to pull requests"
grep -Fq 'contents: read' <<< "${validate_job}" \
  || fail "pull-request validation must explicitly use read-only contents access"
if grep -Eq '(attestations|id-token|packages): write' <<< "${validate_job}"; then
  fail "pull-request validation must not receive publishing permissions"
fi
grep -Fq 'persist-credentials: false' <<< "${validate_job}" \
  || fail "pull-request checkout credentials must not persist"

grep -Fq "if: github.event_name != 'pull_request'" <<< "${publish_job}" \
  || fail "the privileged publishing job must reject pull requests"
grep -Fq 'packages: write' <<< "${publish_job}" \
  || fail "the publishing job must explicitly receive registry access"
grep -Fq 'persist-credentials: false' <<< "${publish_job}" \
  || fail "publishing checkout credentials must not persist"
grep -Fq "rollback_tag=sha-\${short_sha}-run-\${GITHUB_RUN_ID}-\${GITHUB_RUN_ATTEMPT}" \
  <<< "${publish_job}" \
  || fail "rollback tags must be unique to a commit and workflow run attempt"

grep -Fq 'ExecStart=/usr/bin/nextdns run' systemd/nextdns.service \
  || fail "the image must provide deterministic NextDNS systemd integration"

echo "Static validation passed"
