#!/usr/bin/env bash
set -euo pipefail
CROSS=arm-linux-gnueabihf

echo "=== undefined dynamic symbols in our plugin ==="
"${CROSS}-nm" -D --undefined-only /out/libnullmotor.so | awk '{print $NF}' | sort -u > /tmp/undef.txt
wc -l /tmp/undef.txt

echo "=== defined dynamic symbols across reflib ==="
"${CROSS}-nm" -D --defined-only /reflib/*.so 2>/dev/null | awk '{print $NF}' | sort -u > /tmp/def_reflib.txt
wc -l /tmp/def_reflib.txt

echo "=== defined dynamic symbols in sysroot libc/libstdc++/libgcc ==="
("${CROSS}-nm" -D --defined-only /sysroot/lib/arm-linux-gnueabihf/*.so* /sysroot/usr/lib/arm-linux-gnueabihf/*.so* 2>/dev/null || true) | awk '{print $NF}' | sort -u > /tmp/def_sysroot.txt
wc -l /tmp/def_sysroot.txt

echo "=== truly unresolved (in neither reflib nor sysroot) ==="
comm -23 /tmp/undef.txt <(cat /tmp/def_reflib.txt /tmp/def_sysroot.txt | sort -u) || true

echo "=== DT_NEEDED ==="
"${CROSS}-readelf" -d /out/libnullmotor.so | grep NEEDED || true
