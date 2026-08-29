# Deployment procedure

`vm-template-name` is expected to be Rocky Linux, AlmaLinux, or Oracle
Linux 10+.

1. **Terraform** clones a new VM from the pre-existing `vm-template-name`
   template via the Proxmox API (`terraform/`). The fabricator SSH public
   key already lives in the template, so nothing needs to be injected at
   clone time.
2. Terraform waits on the QEMU guest agent and exposes the assigned
   **IPv4 address** as the `vm_ipv4_address` output.
3. The fabricator **private key** is pulled from a secret store at
   provisioning time (`scripts/fetch-secret.sh`) — it is never stored in
   this repo or in Terraform state.
4. An Ansible inventory is rendered from the Terraform output IP and the
   fetched key path (`ansible/inventory/inventory.ini.tpl` →
   `inventory.ini`).
5. **Ansible** (`ansible/`) connects as `fabricator` and runs
   `playbook.yml`, which applies:
   - `base` — enables EPEL (distro-specific), upgrades all packages,
     installs the baseline package set (including `qemu-guest-agent`,
     enabled and started), per
     [instructions/instruction-01.txt](../../instructions/instruction-01.txt).
     `zram-generator` is skipped here (`base_install_zram: false`) — the
     instructions call out Docker hosts as the one case that shouldn't
     get it,
   - `docker-ce` — adds Docker's official RHEL repo and installs
     `docker-ce`, `docker-ce-cli`, `containerd.io`, the buildx and
     compose plugins, enables the `docker` service, and adds `fabricator`
     to the `docker` group,
   - `first-boot` — installs (but does not run) a one-shot systemd service
     that regenerates per-VM identifiers — `machine-id`, SSH host keys —
     plus general cleanup, per
     [instructions/instruction-02.txt](../../instructions/instruction-02.txt).
     It fires on this VM's *next* reboot, not during this Ansible run,
     because it deletes the SSH host keys Ansible's own connection is
     using; a marker file (`/etc/pveservice-first-boot-done`) keeps it to
     exactly one run. **Reboot the VM once after initial provisioning**
     (whenever convenient) to actually trigger it.

`scripts/deploy.sh` runs steps 1–5 locally in order (terraform apply, then
`scripts/configure.sh` for the Ansible half). `scripts/destroy.sh` tears the
VM back down.

## Layout

| Path | Purpose |
|---|---|
| `terraform/` | Clones the VM, outputs its IPv4 |
| `ansible/` | Post-clone configuration, run as `fabricator` (`base` + `docker-ce` roles) |
| `scripts/tf-init.sh` | `terraform init` against GitLab-managed state, used by every other script and by CI |
| `scripts/deploy.sh` | Local convenience wrapper: terraform apply → `configure.sh` |
| `scripts/configure.sh` | Ansible half: fetch key → wait for SSH → ansible-playbook (takes the VM IP as an argument) |
| `scripts/fetch-secret.sh` | Pulls the fabricator private key from Vault/AWS/local/GitLab, pluggable via `SECRET_BACKEND` |
| `scripts/destroy.sh` | `terraform destroy` |
| `.gitlab-ci.yml` | CI pipeline: validate → plan → apply (manual) → configure (manual) → destroy (manual) |

## Running via GitLab CI/CD

This directory's `.gitlab-ci.yml` is included from the repo root's
`.gitlab-ci.yml` — it runs automatically when files under
`vm-docker-regular/` change, or on demand by starting a pipeline with the
variable `VM_TARGET=vm-docker-regular`. `apply`, `configure`, and `destroy`
are manual jobs so nothing happens unattended.

Required project CI/CD variables (Settings > CI/CD > Variables):
- `TF_VAR_pve_api_endpoint`, `TF_VAR_pve_api_token` (masked), `TF_VAR_pve_node`,
  `TF_VAR_vm_template_name`, `TF_VAR_vm_name` — Terraform reads any `TF_VAR_*`
  variable automatically, so no `terraform.tfvars` file is needed in CI.
- `FABRICATOR_PRIVATE_KEY` (masked, protected) — read by `fetch-secret.sh`
  when `SECRET_BACKEND=gitlab` (set in `.gitlab-ci.yml`). Swap for GitLab's
  native Vault/AWS `secrets:` keyword if one of those is already set up.

Terraform state lives in GitLab's managed Terraform state (via the `http`
backend in `terraform/backend.tf`), keyed by `TF_STATE_NAME`, so pipeline
runs don't depend on a runner's local disk. `CI_API_V4_URL`, `CI_PROJECT_ID`
and `CI_JOB_TOKEN` are provided automatically by GitLab; running
`scripts/tf-init.sh` locally instead needs those same variables exported by
hand (with `GITLAB_TOKEN` — a personal/project access token — standing in
for `CI_JOB_TOKEN`).

## Adding a new service on top of this template

Fork/copy this repo per service, then:
- adjust `terraform/terraform.tfvars` (copy from `.example`) for the
  service's VM sizing and name,
- add service-specific roles under `ansible/roles/` and reference them
  from `ansible/playbook.yml`,
- point `SECRET_BACKEND` / the backend-specific env vars in
  `scripts/fetch-secret.sh` at that service's key in the secret store.
