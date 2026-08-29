# guideline-pveservice

Reusable templates for deploying a service as a Proxmox VM: Terraform
clones the VM from a pre-existing template, then (Linux variants) Ansible
configures it over SSH as the `fabricator` user.

## Variants

- [vm-linux-regular/](vm-linux-regular/) — Rocky/AlmaLinux/Oracle Linux
  10+, plain VM, no extra runtime.
- [vm-docker-regular/](vm-docker-regular/) — same, plus a Docker CE
  installation.
- [vm-windows-regular/](vm-windows-regular/) — Windows, Terraform + GitLab
  CI only for now, no Ansible/WinRM half yet.

This is a **template source**, not something you run CI against directly:
each variant is fully self-contained (own `terraform/`, `scripts/`,
`.gitlab-ci.yml`, and `ansible/` where applicable) and is meant to be
**copied out to its own dedicated GitLab repo** — its `.gitlab-ci.yml`
already assumes it will be sitting at that new repo's root. See the
README and `docs/deployment-procedure.md` inside each variant for exact
setup steps, and
[docs/proxmox-template-best-practices.md](docs/proxmox-template-best-practices.md)
for template-level (storage, filesystem, UEFI/TPM) guidance shared across
all three.

## Building the templates

[pve-templates/](pve-templates/) has the scripts that build the three
`vm_template_name` templates the variants above clone from (`vm-oracle10`,
`vm-alma10`, `vm-win2025`) — run on the Proxmox host itself, not part of
the Terraform/Ansible flow, and not something you'd copy alongside a
variant (build the templates once, point any number of deployed repos at
them by name).

## Original requirements

- `vm-template-name` is assumed to already exist (Rocky, AlmaLinux, or
  Oracle Linux 10+).
- Terraform deploys a VM by cloning `vm-template-name` via the Proxmox API.
- After deployment, discover the VM's IPv4 and connect as `fabricator`.
- The `fabricator` public key is already baked into `vm-template-name`; the
  private key lives in a secret store, fetched at deploy time.
- `fabricator` is also the Ansible user for the second component (Ansible).
- One variant additionally installs Docker CE.
- A third variant deploys Windows: Terraform + GitLab CI only for now.
