#!/usr/bin/env bash
# Cross-compiles null_motor (armhf) using Docker.
#
#   ./build.sh
#
# Result: ./out/libnullmotor.so
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

IMAGE=null-motor-cross

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required." >&2
    exit 1
fi

if [ ! -f reflib/libplayercore.so ]; then
    echo "reflib/libplayercore.so missing -- copy the robot's own" >&2
    echo "libplayercore.so/libplayerinterface.so/libplayercommon.so into" >&2
    echo "reflib/ first (from /opt/rockrobo/cleaner/lib/ on the robot)." >&2
    exit 1
fi

docker build -t "$IMAGE" -f docker/Dockerfile .

mkdir -p out
docker run --rm -v "$(pwd)/out":/out "$IMAGE"

echo "=== built: $(pwd)/out/libnullmotor.so ==="
