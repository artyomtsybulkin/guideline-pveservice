#!/usr/bin/env bash
# Ansible half of the deployment: given a VM IPv4 (arg1, or $VM_IPV4), fetch
# the fabricator private key from the secret store, wait for SSH, then run
# the playbook. Split out from deploy.sh so a CI pipeline can run "terraform
# apply" and "ansible configure" as separate, independently-retryable jobs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$ROOT_DIR/ansible"

VM_IPV4="${1:-${VM_IPV4:-}}"
if [[ -z "$VM_IPV4" ]]; then
  echo "usage: $0 <vm-ipv4>  (or set VM_IPV4)" >&2
  exit 1
fi

echo "==> fetching fabricator private key from secret store"
FABRICATOR_KEY_PATH="$("$ROOT_DIR/scripts/fetch-secret.sh")"
trap 'rm -f "$FABRICATOR_KEY_PATH"' EXIT

echo "==> rendering inventory"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/inventory.ini"
sed \
  -e "s|__VM_IPV4__|$VM_IPV4|" \
  -e "s|__FABRICATOR_PRIVATE_KEY_PATH__|$FABRICATOR_KEY_PATH|" \
  "$ANSIBLE_DIR/inventory/inventory.ini.tpl" > "$INVENTORY_FILE"

echo "==> waiting for SSH on $VM_IPV4:22"
for _ in $(seq 1 30); do
  if ssh -i "$FABRICATOR_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
       -o BatchMode=yes "fabricator@$VM_IPV4" true 2>/dev/null; then
    break
  fi
  sleep 5
done

echo "==> ansible-playbook"
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbook.yml"

echo "==> done: $VM_IPV4"
