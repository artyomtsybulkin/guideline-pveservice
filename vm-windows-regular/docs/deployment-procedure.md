# Deployment procedure

Terraform-only for now: no Ansible half. `vm-template-name` is expected to
already have `qemu-guest-agent` and the virtio-win drivers (`vioscsi`,
`netkvm`) installed — see
[../../docs/proxmox-template-best-practices.md](../../docs/proxmox-template-best-practices.md)
for the full template review, including why ReFS can't be the system
volume and why the cloud-init `initialization` block is intentionally
absent from `main.tf`.

1. **Terraform** clones a new VM from the pre-existing `vm_template_name`
   template via the Proxmox API (`terraform/`).
2. Terraform waits on the QEMU guest agent (Windows service, from
   virtio-win) and exposes the assigned **IPv4 address** as the
   `vm_ipv4_address` output.
3. Whatever configuration the template already bakes in is what the VM
   gets — there is no post-clone provisioning step yet. Access (RDP,
   WinRM) and credentials are whatever the template ships with.

`scripts/deploy.sh` runs steps 1–2 locally. `scripts/destroy.sh` tears the
VM back down.

## Layout

| Path | Purpose |
|---|---|
| `terraform/` | Clones the VM, outputs its IPv4 |
| `scripts/tf-init.sh` | `terraform init` against GitLab-managed state, used by every other script and by CI |
| `scripts/deploy.sh` | Local convenience wrapper: terraform apply, print IP |
| `scripts/destroy.sh` | `terraform destroy` |
| `.gitlab-ci.yml` | CI pipeline: validate → plan → apply (manual) → destroy (manual) |

## Running via GitLab CI/CD

This directory's `.gitlab-ci.yml` is included from the repo root's
`.gitlab-ci.yml` — it runs automatically when files under
`vm-windows-regular/` change, or on demand by starting a pipeline with the
variable `VM_TARGET=vm-windows-regular`. `apply` and `destroy` are manual
jobs so nothing happens unattended.

Required project CI/CD variables (Settings > CI/CD > Variables):
- `TF_VAR_pve_api_endpoint`, `TF_VAR_pve_api_token` (masked), `TF_VAR_pve_node`,
  `TF_VAR_vm_template_name`, `TF_VAR_vm_name` — Terraform reads any `TF_VAR_*`
  variable automatically, so no `terraform.tfvars` file is needed in CI.

Terraform state lives in GitLab's managed Terraform state (via the `http`
backend in `terraform/backend.tf`), keyed by `TF_STATE_NAME`, so pipeline
runs don't depend on a runner's local disk — same mechanism as the other
two variants.

## Adding an Ansible/WinRM half later

When post-clone configuration is needed, mirror `vm-linux-regular`'s
pattern: a `configure` stage/job, a WinRM- or SSH-based inventory, and a
`fetch-secret.sh`-style script for the Administrator credential (from a
secret store, the same way `fabricator`'s key is handled for the Linux
variants) rather than a credential baked into the template.
