#!/usr/bin/env bash
# Wrapper: prove issue #9 L2 fix with planted leftover dnsmasq.
set -euo pipefail
REPO="${1:-$(cd "$(dirname "$(realpath "$0")")/.." && pwd)}"
exec bash "${REPO}/tests/prove-l2-fix.sh"
