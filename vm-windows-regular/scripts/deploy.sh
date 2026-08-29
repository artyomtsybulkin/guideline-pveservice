#!/usr/bin/env bash
# Local convenience wrapper: terraform apply, then print the cloned VM's
# IPv4. No Ansible half yet (Terraform + GitLab CI only, see README.md) —
# configuration is whatever the template already bakes in.
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
