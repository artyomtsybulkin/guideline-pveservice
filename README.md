# guideline-pveservice

Reusable templates for deploying a service as a Proxmox VM: Terraform
clones the VM from a pre-existing template (Rocky Linux, AlmaLinux, or
Oracle Linux 10+), then Ansible configures it over SSH as the `fabricator`
user.

## Variants

- [vm-linux-regular/](vm-linux-regular/) — plain VM, no extra runtime.
- [vm-docker-regular/](vm-docker-regular/) — same, plus a Docker CE
  installation.

Each variant is self-contained (own `terraform/`, `ansible/`, `scripts/`,
`.gitlab-ci.yml`) and can be copied out on its own for a new service. See
the README and `docs/deployment-procedure.md` inside each for details.

## GitLab CI/CD

The root [.gitlab-ci.yml](.gitlab-ci.yml) is the only file GitLab
auto-discovers; it `include`s each variant's own `.gitlab-ci.yml`, running
only the variant whose files changed (or the one named by the `VM_TARGET`
pipeline variable). Each variant's pipeline runs `validate` automatically
and gates `plan` → `apply` → `configure` → `destroy` as manual jobs, with
Terraform state kept in GitLab's managed Terraform state backend.

## Original requirements

- `vm-template-name` is assumed to already exist (Rocky, AlmaLinux, or
  Oracle Linux 10+).
- Terraform deploys a VM by cloning `vm-template-name` via the Proxmox API.
- After deployment, discover the VM's IPv4 and connect as `fabricator`.
- The `fabricator` public key is already baked into `vm-template-name`; the
  private key lives in a secret store, fetched at deploy time.
- `fabricator` is also the Ansible user for the second component (Ansible).
- One variant additionally installs Docker CE.
