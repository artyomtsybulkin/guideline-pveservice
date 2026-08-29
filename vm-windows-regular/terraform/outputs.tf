# Exposes the cloned VM's ID and IPv4 address to scripts/CI.

output "vm_id" {
  description = "VMID assigned to the cloned VM."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "vm_ipv4_address" {
  description = "Primary IPv4 address reported by the QEMU guest agent."
  # index 0 of ipv4_addresses is always the loopback interface; index 1 is
  # the first configured NIC.
  value = try(proxmox_virtual_environment_vm.this.ipv4_addresses[1][0], null)
}
