#!/bin/bash
# Compatibility wrapper. The real implementation lives in ./devclean.
# This file exists so older habits / documentation that reference
# devclean.sh keep working.
set -u

_here="$(cd -P "$(dirname "${BASH_SOURCE[0]:-$0}")" >/dev/null 2>&1 && pwd)"
exec "$_here/devclean" "$@"
