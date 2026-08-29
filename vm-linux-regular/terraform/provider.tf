# Configures the Proxmox API connection used by every resource below.
# Credentials are supplied via variables (see variables.tf), which in turn
# should be populated from your secret store / CI variables, never committed
# in terraform.tfvars.
provider "proxmox" {
  endpoint  = var.pve_api_endpoint
  api_token = var.pve_api_token
  insecure  = var.pve_tls_insecure

  ssh {
    agent = false
  }
}
