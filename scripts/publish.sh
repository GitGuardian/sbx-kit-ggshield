#!/usr/bin/env bash
# Publish the gitguardian kit artifact to Docker Hub.
#
# ONE repo, ONE tag:
#   docker.io/<ns>/ggshield-kit:latest
#
# The kit is agent-agnostic - its install step wires the ggshield AI hook for
# every assistant ggshield supports - so there is nothing to fan out over. The
# tag is only a human-facing label: consumers pin by DIGEST (sbx rejects OCI
# tags at consume time).
#
# Usage:
#   ./scripts/publish.sh                    # push to docker.io/gitguardian/ggshield-kit:latest
#   ./scripts/publish.sh <namespace>        # push under <namespace>
#   ./scripts/publish.sh <namespace> <tag>  # push under a tag other than :latest
#
# Requires: `sbx` (a RELEASE build) on PATH, and BOTH `docker login` and
# `sbx login`. The push itself falls back to the Docker credential store, but
# sbx then reads the manifest back to attach the SLSA provenance referrer (and
# the Sigstore bundle under --sign) over its own Docker Hub session; without
# `sbx login` that step fails with "user is not authenticated to Docker: no
# default account profile set". The kit is a kind: mixin, so this pushes the
# OCI *artifact* (spec.yaml + files) - no container image.
set -euo pipefail

NAMESPACE="${1:-gitguardian}"
TAG="${2:-latest}"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIT_LAYER_MEDIA_TYPE="application/vnd.oci.image.layer.v1.tar+gzip"
REPO="docker.io/${NAMESPACE}/ggshield-kit"
REF="${REPO}:${TAG}"

# SBX_KIT_SIGN=1 attaches a keyless Sigstore signature to the push. Keyless
# signing needs an OIDC identity: in CI sbx picks up the ambient provider (for
# GitHub Actions the job needs `permissions: id-token: write`); locally it opens
# a browser. Off by default - what this repo publishes has always been unsigned.
PUSH_FLAGS=()
[ "${SBX_KIT_SIGN:-0}" = "1" ] && PUSH_FLAGS+=(--sign)

echo ">> validating ${KIT_DIR}"
sbx kit validate "${KIT_DIR}"

echo ">> pushing ${REF}"
sbx kit push "${KIT_DIR}" "${REF}" ${PUSH_FLAGS[@]+"${PUSH_FLAGS[@]}"}

echo ">> verifying pushed artifact"
manifest="$(docker buildx imagetools inspect --raw "${REF}")"
if ! grep -qF "${KIT_LAYER_MEDIA_TYPE}" <<<"${manifest}"; then
  echo >&2
  echo "ERROR: ${REF} has no ${KIT_LAYER_MEDIA_TYPE} layer." >&2
  echo "       Released sbx clients cannot resolve this artifact." >&2
  echo "       'sbx version' is probably a dev build; re-push from a release" >&2
  echo "       build. See PUBLISHING.md." >&2
  exit 1
fi

DIGEST="$(docker buildx imagetools inspect "${REF}" | awk '/^Digest:/ { print $2; exit }')"

echo
echo "==================================================================="
echo ">> Published ${REF}"
echo ">> Digest (pin this in README.md / PUBLISHING.md / the Docker Hub overview):"
echo
echo "   ${DIGEST}"
echo
echo ">> Consume it with any agent, e.g.:"
echo "   sbx run claude --kit \"oci://${REPO}@${DIGEST}\" ."
echo "   sbx run codex  --kit \"oci://${REPO}@${DIGEST}\" ."
