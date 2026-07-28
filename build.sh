#!/usr/bin/env bash
# Build script for ostat.
#
#   ./build.sh            -> debug build
#   ./build.sh debug
#   ./build.sh release
#   ./build.sh test       -> run every @(test) proc in src
#
# Compiler diagnostics are rewritten from Odin's native format
#     /path/main.odin(12:5) Error: ...
# into
#     /path/main.odin:12:5 Error: ...
# because Zed's terminal only detects file:line:col when making paths
# clickable. This is the Zed equivalent of Sublime's "file_regex".

set -euo pipefail

cd "$(dirname "$0")"

MODE="${1:-debug}"
# Mirrored in .zed/tasks.json and .zed/debug.json. Change all three together
# or the debugger will silently launch a stale binary from the old path.
NAME="ostat"
SRC="src"
OUT_DIR="build/$MODE"

case "$MODE" in
    debug)
        FLAGS=(-debug -o:none)
        ;;
    release)
        FLAGS=(-o:speed -no-bounds-check)
        ;;
    test)
        FLAGS=(-debug -o:none)
        ;;
    *)
        echo "usage: $0 [debug|release|test]" >&2
        exit 2
        ;;
esac

# vendor:commonmark links "system:cmark", and Homebrew's lib directory is not
# on the default linker path. If you see "library not found for -lcmark",
# run: brew install cmark
#
# An array, and empty when the library is somewhere the linker already looks,
# as it is on Linux. Passing -extra-linker-flags with an empty value is an
# error rather than a no-op.
LINK=()
for dir in /opt/homebrew/lib /usr/local/lib; do
    if [ -e "$dir/libcmark.dylib" ] || [ -e "$dir/libcmark.so" ]; then
        LINK=(-extra-linker-flags:"-L$dir")
        break
    fi
done

# The ${LINK[@]+...} guard is for bash 3.2, which is what macOS ships and
# which treats an empty array as unset under `set -u`.
if [ "$MODE" = "test" ]; then
    odin test "$SRC" "${FLAGS[@]}" ${LINK[@]+"${LINK[@]}"} 2>&1 \
        | sed -E 's/^(.+)\(([0-9]+):([0-9]+)\)/\1:\2:\3/'
    exit "${PIPESTATUS[0]}"
fi

mkdir -p "$OUT_DIR"

odin build "$SRC" -out:"$OUT_DIR/$NAME" "${FLAGS[@]}" \
    ${LINK[@]+"${LINK[@]}"} 2>&1 \
    | sed -E 's/^(.+)\(([0-9]+):([0-9]+)\)/\1:\2:\3/'

echo "built $OUT_DIR/$NAME"
