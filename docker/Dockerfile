# Cross-build environment for null_motor: a Player driver *plugin* (a .so
# dlopen()'d by the player daemon itself via a `plugin` cfg line), targeting
# the robot's own armhf Linux (Ubuntu 14.04 trusty, glibc 2.19).
#
# Two things this needs that a plain client-tool build (see
# ../../roborock-player-client/) doesn't:
#   1. libplayercore headers (Driver, ConfigFile, DriverTable, the
#      generated interface/message definitions) -- obtained the same way
#      roborock-player-client gets its generated player.h: clone Player at
#      the same pinned commit and run its cmake configure + a native build
#      of just `playerinterface`/`playercommon` (never `playercore` itself,
#      sidestepping the same upstream C++17 `bool operator++` bug noted
#      there -- we only need playercore's plain .h files, never compile
#      its .cc sources).
#   2. An ARMHF cross-compiler + sysroot, plus the real
#      libplayercore.so/libplayerinterface.so/libplayercommon.so already
#      running on the robot (copied in as reflib/, see ../fetch-reflib.sh)
#      to link against -- so the plugin binds to the exact symbols/ABI
#      already deployed, rather than a freshly-built libplayercore.so that
#      might not match.
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake git ca-certificates file python3 \
        gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf \
    && rm -rf /var/lib/apt/lists/*

# --- 1. Player source, just enough built natively to generate headers ---
ARG PLAYER_REPO=https://github.com/playerproject/player.git
ARG PLAYER_COMMIT=cb1e0b1349735bcad64eba8846b422f2dc59b768
RUN git clone "$PLAYER_REPO" /opt/player-src \
    && cd /opt/player-src \
    && git checkout "$PLAYER_COMMIT"

RUN mkdir -p /opt/player-src/build && cd /opt/player-src/build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_PLAYERCC=OFF \
        -DBUILD_UTILS=OFF -DBUILD_CC_TESTS=OFF -DBUILD_EXAMPLES=OFF \
        -DBUILD_PYTHONC_BINDINGS=OFF -DBUILD_DOCUMENTATION=OFF \
    && make -j"$(nproc)" playerinterface playercommon

# --- 2. ARMHF sysroot: robot's exact glibc + libstdc++ runtime ---
# (same approach as robocontroller-mini's fork: apt-get download + dpkg-deb
# -x, no execution of ARM code at build time, no QEMU/chroot needed)
RUN sed -i 's/^deb /deb [arch=amd64] /' /etc/apt/sources.list && \
    dpkg --add-architecture armhf && \
    { \
        echo "deb [arch=armhf trusted=yes] http://ports.ubuntu.com/ubuntu-ports trusty main universe"; \
        echo "deb [arch=armhf trusted=yes] http://ports.ubuntu.com/ubuntu-ports trusty-updates main universe"; \
        echo "deb [arch=armhf trusted=yes] http://ports.ubuntu.com/ubuntu-ports trusty-security main universe"; \
    } > /etc/apt/sources.list.d/rockrobo-target.list && \
    apt-get update && \
    mkdir -p /sysroot/dl && cd /sysroot/dl && \
    apt-get download libc6:armhf libc6-dev:armhf linux-libc-dev:armhf libc-dev-bin:armhf \
        libstdc++6:armhf libgcc1:armhf && \
    for f in *.deb; do dpkg-deb -x "$f" /sysroot; done && \
    cd / && rm -rf /sysroot/dl

ENV PLAYER_SRC=/opt/player-src
ENV PLAYER_BUILD=/opt/player-src/build
ENV SYSROOT=/sysroot

COPY reflib/ /reflib/
COPY src/ /src/
COPY docker/build-plugin.sh /usr/local/bin/build-plugin.sh
RUN chmod +x /usr/local/bin/build-plugin.sh

WORKDIR /src
ENTRYPOINT ["/usr/local/bin/build-plugin.sh"]
