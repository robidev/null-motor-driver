#!/usr/bin/env bash
# Cross-compiles null_motor.cc into libnullmotor.so (armhf), linking
# against the robot's own reflib/*.so, and verifies there are no undefined
# symbols before declaring success. Tries the modern default C++11 ABI
# first; if linking reports unresolved __cxx11-mangled symbols (meaning
# the robot's libplayercore.so was actually built pre-GCC5 with the OLD
# std::string/std::list ABI), retries with the old ABI forced.
set -euo pipefail

CROSS=arm-linux-gnueabihf
CXX="${CROSS}-g++"
ARCH_FLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard"
INCLUDES="-I${PLAYER_SRC} -I${PLAYER_SRC}/libplayercore -I${PLAYER_SRC}/libplayerinterface \
          -I${PLAYER_BUILD} -I${PLAYER_BUILD}/libplayerinterface"
LDFLAGS="-L/reflib -Wl,-rpath-link,/reflib"
LIBS="-lplayercore -lplayerinterface -lplayercommon"

OUT=/out
mkdir -p "$OUT"

try_build() {
    local abiflag="$1"
    local outfile="$2"
    echo "=== trying build with ${abiflag:-default ABI} ==="
    "$CXX" -std=c++11 -O2 -Wall -Wextra -fPIC -shared \
        --sysroot="$SYSROOT" $ARCH_FLAGS $abiflag \
        $INCLUDES -o "$outfile" null_motor.cc \
        $LDFLAGS $LIBS
}

if try_build "" "$OUT/libnullmotor.so" 2> /tmp/build.log; then
    echo "link OK with default ABI"
else
    if grep -q '__cxx11' /tmp/build.log; then
        echo "default ABI failed on __cxx11 symbols -- retrying with old ABI"
        cat /tmp/build.log
        try_build "-D_GLIBCXX_USE_CXX11_ABI=0" "$OUT/libnullmotor.so"
    else
        echo "build failed (not an ABI issue):"
        cat /tmp/build.log
        exit 1
    fi
fi

echo "=== checking for undefined symbols against reflib ==="
UNDEF=$("${CROSS}-nm" -D --undefined-only "$OUT/libnullmotor.so" | awk '{print $2}')
MISSING=0
for sym in $UNDEF; do
    # Symbols libc/libstdc++/libgcc itself provides are fine; we only care
    # whether anything we expected FROM libplayercore/interface/common is
    # actually resolvable there or in the sysroot's own libs.
    if ! "${CROSS}-nm" -D --defined-only /reflib/*.so 2>/dev/null | awk '{print $2}' | grep -qx "$sym" \
       && ! "${CROSS}-nm" -D --defined-only "$SYSROOT"/lib/arm-linux-gnueabihf/*.so* "$SYSROOT"/usr/lib/arm-linux-gnueabihf/*.so* 2>/dev/null | awk '{print $2}' | grep -qx "$sym"; then
        echo "UNRESOLVED: $sym"
        MISSING=1
    fi
done

file "$OUT/libnullmotor.so"

if [ "$MISSING" -eq 1 ]; then
    echo "=== WARNING: some symbols did not resolve against reflib or sysroot libs (see above) ==="
    exit 2
fi

echo "=== built: $OUT/libnullmotor.so (all symbols resolved against reflib/sysroot) ==="
