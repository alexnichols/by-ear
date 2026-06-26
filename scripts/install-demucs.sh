#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "install-demucs.sh is deprecated; installing local MLX AI instead." >&2
exec "$SCRIPT_DIR/install-local-ai.sh"
