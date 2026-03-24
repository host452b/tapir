#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Cleaning release artifacts only..."
rm -rf "$ROOT/src-tauri/target/release/bundle"
rm -f "$ROOT/src-tauri/target/release/tapir"
rm -f "$ROOT"/*.pkg
rm -f "$ROOT"/*.dmg
echo "==> Done."
