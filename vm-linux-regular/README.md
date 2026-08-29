# vm-linux-regular

A plain service VM: Terraform clones it from `vm-template-name`, Ansible
configures it over SSH as `fabricator`. No extra runtime installed.

Template OS: Rocky Linux, AlmaLinux, or Oracle Linux 10+.

See [docs/deployment-procedure.md](docs/deployment-procedure.md) for the
full walkthrough.

## Layout

- `terraform/` — clones `vm-template-name` via the Proxmox API, outputs the
  new VM's IPv4 address (via the QEMU guest agent)
- `ansible/` — configures the VM over SSH as `fabricator` (`base` role:
  package updates, base packages). Add your own services/applications as
  extra roles under `ansible/roles/` — see
  [ansible/roles/README.md](ansible/roles/README.md)
- `scripts/deploy.sh` — runs the full flow: terraform apply → fetch
  fabricator's private key from a secret store → wait for SSH → ansible-playbook
- `scripts/destroy.sh` — tears the VM down

## Quick start

```sh
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# fill in terraform.tfvars with your Proxmox endpoint/token/node

export SECRET_BACKEND=vault           # or: aws, local, gitlab
export VAULT_SECRET_PATH=secret/data/pve/fabricator

./scripts/deploy.sh
```

## GitLab CI/CD

`.gitlab-ci.yml` here (included from the repo root) runs `validate` on
every change and gates `plan`/`apply`/`configure`/`destroy` as manual
jobs. See "Running via GitLab CI/CD" in
[docs/deployment-procedure.md](docs/deployment-procedure.md) for the
required CI/CD variables.
