#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Cleaning Rust build artifacts..."
rm -rf "$ROOT/src-tauri/target"
echo "==> Done."
