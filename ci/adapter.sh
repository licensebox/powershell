#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec pwsh -NoProfile -NonInteractive -File tests/adapter.ps1
