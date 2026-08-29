# Clones vm-template-name into a new VM via the Proxmox API.
#
# Resolve the pre-existing template by name so callers only ever need to know
# "vm-template-name", not its numeric VMID.
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

  network_device {
    bridge = var.vm_network_bridge
  }

  # Required so Terraform/Ansible can discover the DHCP-assigned IPv4 address
  # after boot instead of us having to hardcode it.
  agent {
    enabled = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  # The fabricator SSH public key already lives in the template's
  # authorized_keys — nothing to inject here. The matching private key is
  # fetched from the secret store at provisioning time (see scripts/).

  lifecycle {
    ignore_changes = [
      clone,
    ]
  }
}
