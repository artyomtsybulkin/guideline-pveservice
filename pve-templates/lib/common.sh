#!/usr/bin/env bash
# Shared defaults/helpers for the template-build scripts in this directory.
# These scripts run ON the Proxmox host itself (as root, from `pvesh`/`qm`'s
# own shell) — they are not part of this repo's Terraform/Ansible flow,
# which assumes the templates they produce already exist.

: "${PVE_STORAGE:=vm-directory}"   # matches the vm_datastore_id default in ../vm-*-regular/terraform
: "${PVE_BRIDGE:=vmbr0}"           # untagged (no vlan_id), matches vm_network_bridge default

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run this as root on the Proxmox host." >&2
    exit 1
  fi
}

require_vmid_free() {
  local vmid="$1"
  if qm status "$vmid" &>/dev/null; then
    echo "VMID $vmid is already in use. Pick a different VMID (VMID=... env var) or remove it first." >&2
    exit 1
  fi
}
