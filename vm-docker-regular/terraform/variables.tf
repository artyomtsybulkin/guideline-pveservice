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
  description = "Name of the pre-existing VM template to clone from. Expected to be Rocky, AlmaLinux or Oracle Linux 10+."
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
  default     = 2
}

variable "vm_memory" {
  description = "Memory in MB."
  type        = number
  default     = 2048
}

variable "vm_disk_size" {
  description = "Primary disk size in GB. Must be >= the template's disk size."
  type        = number
  default     = 20
}

variable "vm_datastore_id" {
  description = "Datastore to place the cloned disk on."
  type        = string
  default     = "local-lvm"
}

variable "vm_network_bridge" {
  description = "Bridge to attach the VM's network device to."
  type        = string
  default     = "vmbr0"
}
