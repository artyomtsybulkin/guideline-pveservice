#!/usr/bin/env bash
# Local convenience wrapper for the full flow: terraform apply, then hand
# the resulting IP to configure.sh for the Ansible half. CI runs these two
# halves as separate jobs instead (see ../.gitlab-ci.yml).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"

echo "==> terraform apply"
"$ROOT_DIR/scripts/tf-init.sh"
terraform -chdir="$TF_DIR" apply -auto-approve

VM_IPV4="$(terraform -chdir="$TF_DIR" output -raw vm_ipv4_address)"
if [[ -z "$VM_IPV4" || "$VM_IPV4" == "null" ]]; then
  echo "vm_ipv4_address output is empty; the QEMU guest agent may not have reported yet" >&2
  exit 1
fi
echo "==> VM IPv4: $VM_IPV4"

"$ROOT_DIR/scripts/configure.sh" "$VM_IPV4"
