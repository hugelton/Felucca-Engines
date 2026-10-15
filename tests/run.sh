#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Leo Kuroshita (@kurogedelic), Hügelton Instruments
# Felucca-Engines' own test: the tables, the standalone host (tests/fe_host.c), its renders against
# tests/golden.txt. Run from anywhere:  sh tests/run.sh   (CC=... to pick the compiler; UPDATE=1 rewrites
# the golden file: only for a reviewed, intended change of the sound)
set -e
cd "$(dirname "$0")/.."
mkdir -p build
python3 tools/gen_engine_tables.py build/fe_tables.h
${CC:-cc} -O2 -std=c99 -Wall -Wextra -Wno-unused-function -Wno-unused-parameter -Ibuild \
    -o build/fe_host tests/fe_host.c
build/fe_host > build/renders.txt
if [ "${UPDATE:-0}" = 1 ]; then
    cp build/renders.txt tests/golden.txt
    echo "tests/golden.txt rewritten ($(wc -l < tests/golden.txt | tr -d ' ') renders)"
    exit 0
fi
if diff -u tests/golden.txt build/renders.txt; then
    echo "ok: $(wc -l < tests/golden.txt | tr -d ' ') renders as in tests/golden.txt"
else
    echo "FAIL: the renders above differ from tests/golden.txt"
    exit 1
fi

# ANALOG signed scaling: frozen audio hash, then the same sweep without UBSan exclusions.
${CC:-cc} -O2 -std=c99 -Wall -Wextra -Wno-unused-function -Wno-unused-parameter -Ibuild \
    -o build/analog_signed_test tests/analog_signed_test.c
build/analog_signed_test
SAN="-O1 -g -fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer"
if [ "${SANITIZE:-1}" = 0 ]; then
    echo "skip: ANALOG strict ASan/UBSan (SANITIZE=0)"
else
    printf 'int main(void){return 0;}\n' > build/san_probe.c
    if ${CC:-cc} $SAN -o build/san_probe build/san_probe.c 2>/dev/null && build/san_probe; then
        ${CC:-cc} $SAN -std=c99 -Wno-unused-function -Wno-unused-parameter -Ibuild \
            -o build/analog_signed_strict tests/analog_signed_test.c
        build/analog_signed_strict
    else
        echo "skip: ANALOG strict ASan/UBSan (compiler/runtime unavailable)"
    fi
fi

# LOFI negative quantisation: unchanged samples, with strict sanitizer coverage.
${CC:-cc} -O2 -std=c99 -Wall -Wextra -Wno-unused-function -Wno-unused-parameter -Ibuild \
    -o build/lofi_signed_test tests/lofi_signed_test.c
build/lofi_signed_test
if [ "${SANITIZE:-1}" = 0 ]; then
    echo "skip: LOFI strict ASan/UBSan (SANITIZE=0)"
elif ${CC:-cc} $SAN -o build/san_probe build/san_probe.c 2>/dev/null && build/san_probe; then
    ${CC:-cc} $SAN -std=c99 -Wno-unused-function -Wno-unused-parameter -Ibuild \
        -o build/lofi_signed_strict tests/lofi_signed_test.c
    build/lofi_signed_strict
else
    echo "skip: LOFI strict ASan/UBSan (compiler/runtime unavailable)"
fi
