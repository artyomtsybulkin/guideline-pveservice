# Per-deployment configuration for this VM. Commit this file — it holds
# no secrets. Connection details (pve_api_endpoint, pve_api_token,
# pve_node) come from GitLab CI/CD variables instead (TF_VAR_pve_api_endpoint
# etc.) — see ../.gitlab-ci.yml and ../README.md.

vm_name          = "svc-win-01"
vm_template_name = "vm-win2025"   # whichever Proxmox template you built

# Uncomment to override terraform/variables.tf's defaults:
# vm_id             = null   # leave null to auto-assign the next free VMID
# vm_cores          = 4
# vm_memory         = 8192
# vm_disk_size      = 128
# vm_datastore_id   = "vm-directory"
# vm_network_bridge = "vmbr0"
