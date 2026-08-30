# Deployment procedure

Terraform-only for now: no Ansible half. The Proxmox template
(`vm_template_name`) is expected to already have `qemu-guest-agent` and
the virtio-win drivers (`vioscsi`, `netkvm`) installed — see this repo's
monorepo source (`docs/proxmox-template-best-practices.md`) for the full
template review, including why ReFS can't be the system volume and why
the cloud-init `initialization` block is intentionally absent from
`main.tf`, if you have access to it.

1. **Terraform** clones a new VM from the pre-existing template via the
   Proxmox API (`terraform/`).
2. Terraform waits on the QEMU guest agent (Windows service, from
   virtio-win) and exposes the assigned **IPv4 address** as the
   `vm_ipv4_address` output.
3. Whatever configuration the template already bakes in is what the VM
   gets — there is no post-clone provisioning step yet. Access (RDP,
   WinRM) and credentials are whatever the template ships with.

`scripts/deploy.sh` runs steps 1–2 locally. `scripts/destroy.sh` tears the
VM back down. CI runs the same steps as separate jobs instead (below).

## Layout

| Path | Purpose |
|---|---|
| `terraform/` | Clones the VM, outputs its IPv4 |
| `terraform/terraform.tfvars` | **Committed** per-deployment config: `vm_name`, `vm_template_name`, sizing |
| `scripts/tf-init.sh` | `terraform init` against GitLab-managed state, used by every other script and by CI |
| `scripts/deploy.sh` | Local convenience wrapper: terraform apply, print IP |
| `scripts/destroy.sh` | `terraform destroy` |
| `.gitlab-ci.yml` | CI pipeline: security → validate → plan → apply (manual) → destroy (manual) |

## Security scanning

The `security` stage runs [Trivy](https://github.com/aquasecurity/trivy)
(`trivy fs --scanners misconfig,secret .`) before anything else — Terraform
misconfigurations and accidentally-committed secrets, no vulnerability DB
download needed. It fails the pipeline on any `HIGH`/`CRITICAL` finding;
lower `--severity` or drop `--exit-code 1` in `.gitlab-ci.yml`'s `trivy`
job to make it advisory instead.

## Running via GitLab CI/CD

This `.gitlab-ci.yml` is meant to sit at the root of its own dedicated
GitLab repo (copy the whole `vm-windows-regular/` folder out — its
contents become that repo's root). `validate` runs automatically on
every push; `plan`, `apply`, and `destroy` are manual jobs so nothing
happens unattended.

Required CI/CD variables (Settings > CI/CD > Variables) — connection
details, which never belong in a committed file:
- `TF_VAR_pve_api_endpoint`, `TF_VAR_pve_api_token` (masked), `TF_VAR_pve_node`.

Everything else (`vm_name`, `vm_template_name`, `vm_id`, sizing) comes
from the committed `terraform/terraform.tfvars` — edit that file directly
rather than adding more CI/CD variables. (Any `TF_VAR_<name>` you do set
still overrides the matching value from the file, e.g. for a one-off
change without touching it.)

Terraform state lives in GitLab's managed Terraform state (via the `http`
backend in `terraform/backend.tf`), so pipeline runs don't depend on a
runner's local disk.

## Adding an Ansible/WinRM half later

When post-clone configuration is needed, mirror the Linux variants'
pattern: a `configure` stage/job, a WinRM- or SSH-based inventory, and a
`fetch-secret.sh`-style script for the Administrator credential (from a
secret store, the same way `fabricator`'s key is handled there) rather
than a credential baked into the template.
