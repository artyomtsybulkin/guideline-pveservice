# vm-windows-regular

Terraform + GitLab CI only, for now: clones a Windows VM from a
pre-existing template. No Ansible/WinRM configuration step yet — see
[docs/deployment-procedure.md](docs/deployment-procedure.md) for how to add
one later.

Template requirements: `qemu-guest-agent` (Windows service) and the
virtio-win drivers already installed. See this repo's monorepo source
(`docs/proxmox-template-best-practices.md`) for the full Windows-on-Proxmox
review (TPM, ostype, NTFS vs ReFS, storage) if you have access to it.

This folder is meant to be copied out to its own dedicated GitLab repo —
its `.gitlab-ci.yml` already assumes it's sitting at that repo's root.

## Setup

1. **Copy this whole folder** to a new, dedicated GitLab repo (its
   contents become that repo's root — `terraform/`, `.gitlab-ci.yml`,
   etc. directly at the top level).

2. **Configure the deployment** — two places, no overlap:
   - `terraform/terraform.tfvars` (already committed, edit directly):
     `vm_name`, `vm_template_name`, and optionally `vm_id`, `vm_cores`,
     `vm_memory`, `vm_disk_size`, `vm_datastore_id`, `vm_network_bridge`.
   - GitLab CI/CD variables (Settings > CI/CD > Variables) — connection
     details, which never belong in a committed file:
     `TF_VAR_pve_api_endpoint`, `TF_VAR_pve_api_token` (masked),
     `TF_VAR_pve_node`. See
     [docs/deployment-procedure.md](docs/deployment-procedure.md) for
     exactly what each one is.

3. **Run the pipeline** — push to the repo (or trigger one manually) and
   run the jobs in order: `security` (Trivy scan) → `validate` (both
   automatic) → `plan` → `apply` → `destroy` (the last two are manual
   gates).

## Layout

- `terraform/` — clones the template via the Proxmox API, outputs the new
  VM's IPv4 address (via the QEMU guest agent)
- `terraform/terraform.tfvars` — committed per-deployment config
- `scripts/deploy.sh` — terraform apply, prints the IP (local runs only)
- `scripts/destroy.sh` — tears the VM down
- `.gitlab-ci.yml` — `security` (Trivy scan) → `validate` (both
  automatic) → `plan` → `apply` (manual) → `destroy` (manual)

See [docs/deployment-procedure.md](docs/deployment-procedure.md) for the
full walkthrough.
