# Deployment procedure

The Proxmox template (`vm_template_name`) is expected to be Rocky Linux,
AlmaLinux, or Oracle Linux 10+ — the `base` role uses `dnf`. Build one
with `../pve-templates/` if you don't have one yet.

1. **Terraform** clones a new VM from the pre-existing template via the
   Proxmox API (`terraform/`). The fabricator SSH public key already
   lives in the template, so nothing needs to be injected at clone time.
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
     enabled and started) and `zram-generator`,
   - `first-boot` — installs (but does not run) a one-shot systemd service
     that regenerates per-VM identifiers — `machine-id`, SSH host keys —
     plus general cleanup. It fires on this VM's *next* reboot, not during
     this Ansible run, because it deletes the SSH host keys Ansible's own
     connection is using; a marker file (`/etc/pveservice-first-boot-done`)
     keeps it to exactly one run. **Reboot the VM once after initial
     provisioning** (whenever convenient) to actually trigger it,
   - any custom roles listed in `service_roles` (`ansible/group_vars/all.yml`)
     — see [Adding a service/application](#adding-a-serviceapplication)
     below.

`scripts/deploy.sh` runs steps 1–5 locally in order (terraform apply, then
`scripts/configure.sh` for the Ansible half). `scripts/destroy.sh` tears the
VM back down. CI runs the same two halves as separate jobs instead (below).

## Layout

| Path | Purpose |
|---|---|
| `terraform/` | Clones the VM, outputs its IPv4 |
| `terraform/terraform.tfvars` | **Committed** per-deployment config: `vm_name`, `vm_template_name`, sizing |
| `ansible/` | Post-clone configuration, run as `fabricator` |
| `ansible/group_vars/all.yml` | **Committed** Ansible vars, incl. `service_roles` |
| `scripts/tf-init.sh` | `terraform init` against GitLab-managed state, used by every other script and by CI |
| `scripts/deploy.sh` | Local convenience wrapper: terraform apply → `configure.sh` |
| `scripts/configure.sh` | Ansible half: fetch key → wait for SSH → ansible-playbook (takes the VM IP as an argument) |
| `scripts/fetch-secret.sh` | Pulls the fabricator private key from Vault/AWS/local/GitLab, pluggable via `SECRET_BACKEND` |
| `scripts/destroy.sh` | `terraform destroy` |
| `.gitlab-ci.yml` | CI pipeline: validate → plan → apply (manual) → configure (manual) → destroy (manual) |

## Running via GitLab CI/CD

This `.gitlab-ci.yml` is meant to sit at the root of its own dedicated
GitLab repo (copy the whole `vm-linux-regular/` folder out — its
contents become that repo's root). `validate` runs automatically on
every push; `plan`, `apply`, `configure`, and `destroy` are manual jobs
so nothing happens unattended.

Required CI/CD variables (Settings > CI/CD > Variables) — connection
details and secrets, which never belong in a committed file:
- `TF_VAR_pve_api_endpoint`, `TF_VAR_pve_api_token` (masked), `TF_VAR_pve_node`.
- `FABRICATOR_PRIVATE_KEY` (masked, protected) — read by `fetch-secret.sh`
  when `SECRET_BACKEND=gitlab` (set in `.gitlab-ci.yml`). Swap for GitLab's
  native Vault/AWS `secrets:` keyword if one of those is already set up.

Everything else (`vm_name`, `vm_template_name`, `vm_id`, sizing) comes
from the committed `terraform/terraform.tfvars` — edit that file directly
rather than adding more CI/CD variables. (Any `TF_VAR_<name>` you do set
still overrides the matching value from the file, e.g. for a one-off
change without touching it.)

Terraform state lives in GitLab's managed Terraform state (via the `http`
backend in `terraform/backend.tf`), so pipeline runs don't depend on a
runner's local disk. `CI_API_V4_URL`, `CI_PROJECT_ID` and `CI_JOB_TOKEN`
are provided automatically by GitLab; running `scripts/tf-init.sh` locally
instead needs those same variables exported by hand (with `GITLAB_TOKEN`
— a personal/project access token — standing in for `CI_JOB_TOKEN`).

## Adding a service/application

Drop a new role under `ansible/roles/<name>/` (same layout as
`base`/`first-boot`) and list it in `ansible/group_vars/all.yml`'s
`service_roles`:

```yaml
service_roles:
  - my-service
```

`ansible/playbook.yml` applies every role in `service_roles`, in order,
after `base` and `first-boot` — no changes to the playbook itself needed.
See [ansible/roles/README.md](../ansible/roles/README.md).
