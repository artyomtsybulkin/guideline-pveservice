#!/usr/bin/env bash
# Tears down the VM created by deploy.sh / the CI apply job.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/scripts/tf-init.sh"
terraform -chdir="$ROOT_DIR/terraform" destroy
