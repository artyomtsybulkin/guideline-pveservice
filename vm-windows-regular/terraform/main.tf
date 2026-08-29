# Clones vm_template_name into a new Windows VM via the Proxmox API.
#
# Resolve the pre-existing template by name so callers only ever need to
# know the template's name, not its numeric VMID.
data "proxmox_virtual_environment_vms" "template" {
  filter {
    name   = "name"
    values = [var.vm_template_name]
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.vm_name
  node_name = var.pve_node
  vm_id     = var.vm_id

  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    full  = true
  }

  cpu {
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    interface    = "scsi0"
    size         = var.vm_disk_size
    datastore_id = var.vm_datastore_id
  }

  # No vlan_id set: vmbr0 is used untagged.
  network_device {
    bridge = var.vm_network_bridge
  }

  # Required so Terraform can discover the VM's IPv4 after boot. Needs the
  # qemu-guest-agent Windows service installed in the template (see
  # ../docs/deployment-procedure.md).
  agent {
    enabled = true
  }

  # No cloud-init `initialization` block: Proxmox's built-in cloud-init
  # does not configure Windows guests. Networking comes from the
  # template's own DHCP-enabled NIC.

  lifecycle {
    ignore_changes = [
      clone,
    ]
  }
}
