# syntax=docker/dockerfile:1
# Overlay for the gitguardian mixin: only /opt/ggshield and its launcher land
# on the agent's image.
FROM debian:trixie-slim AS build
ARG GGSHIELD_VERSION
ARG TARGETARCH
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Install ggshield from a pinned, digest-verified GitHub release (no curl|sh,
# version AND SHA256 pinned in git). The release ships a self-contained
# PyInstaller bundle, so we extract the whole tree to /opt and symlink the
# launcher onto PATH. To bump: add the new version's per-arch SHA256 below and
# change the `version` arg default in gitguardian.yaml.
#
# Held at 1.53.0: 1.54.0 ships a broken certificate bundle, reported to the
# ggshield team. Do not bump past 1.53.0 until that lands, and note 1.53.0 has
# no AI hook for Mistral Vibe - that assistant arrived in 1.54.0.
RUN set -eu; \
    case "${GGSHIELD_VERSION}/${TARGETARCH}" in \
      1.53.0/amd64) \
        SLUG="x86_64-unknown-linux-gnu"; \
        SHA256="234d1a62ea7b769695c7e5aee8f29e9d0069cd09b4e5b67493d3b529abb44e4a" ;; \
      1.53.0/arm64) \
        SLUG="aarch64-unknown-linux-gnu"; \
        SHA256="097616513fe7a4f25831a464b8968b124af32d274e2ce006e388800605696b20" ;; \
      *) \
        echo "no pinned ggshield digest for ${GGSHIELD_VERSION} on ${TARGETARCH}" >&2; \
        exit 1 ;; \
    esac; \
    DIRNAME="ggshield-${GGSHIELD_VERSION}-${SLUG}"; \
    URL="https://github.com/GitGuardian/ggshield/releases/download/v${GGSHIELD_VERSION}/${DIRNAME}.tar.gz"; \
    curl --proto '=https' --tlsv1.2 -fsSL -o /tmp/ggshield.tgz "$URL"; \
    echo "${SHA256}  /tmp/ggshield.tgz" | sha256sum -c -; \
    mkdir -p /out/opt /out/usr/local/bin; \
    # --no-same-owner: overlay files must be owned by root, not the tarball's uids.
    tar --no-same-owner -C /out/opt -xzf /tmp/ggshield.tgz; \
    mv "/out/opt/${DIRNAME}" /out/opt/ggshield; \
    ln -s /opt/ggshield/ggshield /out/usr/local/bin/ggshield; \
    rm -f /tmp/ggshield.tgz; \
    /out/opt/ggshield/ggshield --version | grep -F "version ${GGSHIELD_VERSION}"

FROM scratch
COPY --from=build /out /
