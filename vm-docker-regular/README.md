# vm-docker-regular

A service VM with Docker CE installed: Terraform clones it from a Proxmox
template, Ansible installs Docker CE and configures it over SSH as
`fabricator`.

Template OS: Rocky Linux, AlmaLinux, or Oracle Linux 10+.

This folder is meant to be copied out to its own dedicated GitLab repo —
its `.gitlab-ci.yml` already assumes it's sitting at that repo's root.

## Setup

1. **Copy this whole folder** to a new, dedicated GitLab repo (its
   contents become that repo's root — `terraform/`, `ansible/`,
   `.gitlab-ci.yml`, etc. directly at the top level).

2. **Configure the deployment** — two places, no overlap:
   - `terraform/terraform.tfvars` (already committed, edit directly):
     `vm_name`, `vm_template_name`, and optionally `vm_id`, `vm_cores`,
     `vm_memory`, `vm_disk_size`, `vm_datastore_id`, `vm_network_bridge`.
   - GitLab CI/CD variables (Settings > CI/CD > Variables) — connection
     details and secrets, which never belong in a committed file:
     `TF_VAR_pve_api_endpoint`, `TF_VAR_pve_api_token` (masked),
     `TF_VAR_pve_node`, `FABRICATOR_PRIVATE_KEY` (masked, protected).
     See [docs/deployment-procedure.md](docs/deployment-procedure.md) for
     exactly what each one is.

3. **Add your own services/applications** (optional):
   - a role: drop it under `ansible/roles/<name>/` and list it in
     `ansible/group_vars/all.yml`'s `service_roles`. See
     [ansible/roles/README.md](ansible/roles/README.md).
   - just a file or two: create `ansible/files/` and drop files there
     mirroring the target's absolute paths (e.g.
     `ansible/files/opt/myapp/docker-compose.yml` →
     `/opt/myapp/docker-compose.yml`) — copied onto the VM automatically.
     See "Adding custom files" in
     [docs/deployment-procedure.md](docs/deployment-procedure.md).

4. **Run the pipeline** — push to the repo (or trigger one manually) and
   run the jobs in order: `validate` (automatic) → `plan` → `apply` →
   `configure` → `destroy` (the last three are manual gates).

## Layout

- `terraform/` — clones the template via the Proxmox API, outputs the new
  VM's IPv4 address (via the QEMU guest agent)
- `ansible/` — configures the VM over SSH as `fabricator`:
  - `base` — package updates, base packages
  - `docker-ce` — Docker's official RHEL repo, `docker-ce` +
    `docker-ce-cli` + `containerd.io` + buildx/compose plugins, enables
    the `docker` service, adds `fabricator` to the `docker` group
  - plus anything in `service_roles` — see
    [ansible/roles/README.md](ansible/roles/README.md)
- `scripts/` — what the CI jobs (and `deploy.sh`/`destroy.sh` for local
  runs) call internally; see [docs/deployment-procedure.md](docs/deployment-procedure.md)
- `.gitlab-ci.yml` — `validate` (automatic) → `plan` → `apply` (manual) →
  `configure` (manual) → `destroy` (manual)

See [docs/deployment-procedure.md](docs/deployment-procedure.md) for the
full walkthrough.
