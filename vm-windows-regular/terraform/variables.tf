# Input variables: Proxmox connection details, target node, and VM sizing.
# In CI these are supplied as TF_VAR_<name> environment variables instead of
# a tfvars file (see ../.gitlab-ci.yml).

variable "pve_api_endpoint" {
  description = "Proxmox VE API URL, e.g. https://pve.example.local:8006/"
  type        = string
}

variable "pve_api_token" {
  description = "Proxmox API token in the form 'user@realm!token-id=uuid'. Pull from a secret store, not tfvars in git."
  type        = string
  sensitive   = true
}

variable "pve_tls_insecure" {
  description = "Skip TLS verification against the PVE API (only for self-signed lab certs)."
  type        = bool
  default     = false
}

variable "pve_node" {
  description = "Target Proxmox node to place the cloned VM on."
  type        = string
}

variable "vm_template_name" {
  description = "Name of the pre-existing Windows VM template to clone from (must already have qemu-guest-agent and the virtio-win drivers installed)."
  type        = string
}

variable "vm_name" {
  description = "Name for the new VM."
  type        = string
}

variable "vm_id" {
  description = "Optional explicit VMID. Leave null to let Proxmox auto-assign the next free ID."
  type        = number
  default     = null
}

variable "vm_cores" {
  description = "Number of vCPU cores."
  type        = number
  default     = 4
}

variable "vm_memory" {
  description = "Memory in MB."
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "Primary (system) disk size in GB. Must be >= the template's disk size."
  type        = number
  default     = 80
}

variable "vm_datastore_id" {
  description = "Datastore to place the cloned disk on. Use a zfspool-type storage on the ZFS RAID10 pool, not a directory storage, for raw (non-qcow2) disks."
  type        = string
  default     = "local-lvm"
}

variable "vm_network_bridge" {
  description = "Bridge to attach the VM's network device to."
  type        = string
  default     = "vmbr0"
}
