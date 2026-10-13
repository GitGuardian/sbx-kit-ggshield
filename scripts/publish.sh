#!/usr/bin/env bash
# Publish the gitguardian kit to Docker Hub.
#
# ONE repo, ONE advertised tag:
#   docker.io/<ns>/ggshield-kit:latest   (plus :<ggshield version>)
#
# The kit is agent-agnostic - its install hook wires the ggshield AI hook for
# every assistant ggshield supports - so there is nothing to fan out over.
#
# Usage:
#   ./scripts/publish.sh                    # push to docker.io/gitguardian/ggshield-kit:latest
#   ./scripts/publish.sh <namespace>        # push under <namespace>
#   ./scripts/publish.sh <namespace> <tag>  # push under a tag other than :latest
#
# Requires: `docker login` and a `docker buildx` builder able to build
# linux/amd64 and linux/arm64. A v3 kit is a plain OCI image built from
# gitguardian.yaml; no sbx is needed to publish. KIT_REGISTRY overrides
# docker.io (e.g. a local test registry).
set -euo pipefail

NAMESPACE="${1:-gitguardian}"
TAG="${2:-latest}"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${KIT_REGISTRY:-docker.io}/${NAMESPACE}/ggshield-kit"
REF="${REPO}:${TAG}"
VERSION="$(sed -n '/^args:/,/^[a-z]/s/^    default: "\(.*\)"$/\1/p' "${KIT_DIR}/gitguardian.yaml" | head -1)"

echo ">> building and pushing ${REF} (ggshield ${VERSION})"
docker buildx build "${KIT_DIR}" -f "${KIT_DIR}/gitguardian.yaml" \
  --platform linux/amd64,linux/arm64 --provenance=true \
  -t "${REF}" -t "${REPO}:${VERSION}" --push

echo ">> verifying pushed artifact"
if ! docker buildx imagetools inspect --raw "${REF}" | grep -q '"vnd.docker.sandbox.kit.schema-version": *"3"'; then
  echo "ERROR: ${REF} carries no v3 kit descriptor." >&2
  exit 1
fi

DIGEST="$(docker buildx imagetools inspect "${REF}" | awk '/^Digest:/ { print $2; exit }')"

echo
echo "==================================================================="
echo ">> Published ${REF}"
echo ">> Digest:"
echo
echo "   ${DIGEST}"
echo
echo ">> Consume it with any agent, e.g.:"
echo "   sbx run claude --kit \"oci://${REF}\" ."
echo "   sbx run codex  --kit \"oci://${REF}\" ."
