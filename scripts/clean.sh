#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Cleaning ALL build artifacts..."

# Frontend
rm -rf "$ROOT/node_modules"
rm -rf "$ROOT/dist"
rm -f "$ROOT/.tsbuildinfo"

# Rust
rm -rf "$ROOT/src-tauri/target"

# Vite cache
rm -rf "$ROOT/.vite"

echo "==> Clean complete."
