#!/bin/sh
# Run the test suite in a clean Debian container.
#
#   sh tests/docker.sh [filter]
#
# The repository is mounted read-only and cloned inside the container, so the
# committed file modes are used, with uncommitted changes copied over.
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
docker run --rm -v "$repo:/repo:ro" debian:bookworm-slim bash -c '
set -e
apt-get update -qq >/dev/null && apt-get install -y -qq zsh git ca-certificates >/dev/null
git config --global --add safe.directory "*"
git clone -q /repo /work && cd /repo
git ls-files -m -o --exclude-standard -z | xargs -0 -r cp --parents -t /work
cd /work && bash tests/run.sh "$@"
' tests "$@"
