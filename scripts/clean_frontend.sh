#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Cleaning frontend artifacts..."
rm -rf "$ROOT/node_modules"
rm -rf "$ROOT/dist"
rm -rf "$ROOT/.vite"
rm -f "$ROOT/.tsbuildinfo"
echo "==> Done. Run 'npm install' to restore node_modules."
