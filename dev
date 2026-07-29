#!/usr/bin/env bash
# Build the documentation site and serve it.
#
#   ./dev            build with drafts and future posts, serve on $PORT
#   ./dev --build    release build, no drafts, no server
#   ./dev --clean    discard the output tree first, then serve
#
# PORT overrides the port, default 1313.
#
# There is no file watcher. Rebuild with ctrl-c and rerun, or run
# `./dev --build` from the editor while the server keeps running.
set -euo pipefail

cd "$(dirname "$0")"

SITE="site"
OUT="public"
PORT="${PORT:-1313}"

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
    --build)
        # A release build, because this is the one that claims to be what a
        # deploy publishes. It used to say that while running the debug binary.
        ./build.sh release
        rm -rf "$OUT"
        ./build/release/ostat build "$SITE" -o "$OUT"
        echo
        echo "Built to $OUT/. This is what a deploy would publish."
        ;;

    --clean | "")
        if [ "${1:-}" = "--clean" ]; then
            rm -rf "$OUT"
        fi

        ./build.sh debug
        ./build/debug/ostat build "$SITE" -o "$OUT" -drafts -future

        if ! command -v python3 > /dev/null; then
            echo
            echo "Built to $OUT/, but python3 is missing so there is no server." >&2
            echo "Serve $OUT/ with anything you like, or use ./dev --build." >&2
            exit 1
        fi

        echo
        echo "serving $OUT/ on http://localhost:$PORT"
        exec python3 -m http.server "$PORT" --directory "$OUT"
        ;;

    -h | --help)
        usage
        ;;

    *)
        # Anything unrecognised used to fall through to a full build and serve.
        echo "dev: unknown option ${1}" >&2
        echo >&2
        usage >&2
        exit 2
        ;;
esac
