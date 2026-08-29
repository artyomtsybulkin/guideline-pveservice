# vm-docker-regular

Same as [vm-linux-regular](../vm-linux-regular), plus a `docker-ce` role:
Terraform clones the VM from `vm-template-name`, Ansible installs Docker CE
and adds `fabricator` to the `docker` group.

Template OS: Rocky Linux, AlmaLinux, or Oracle Linux 10+.

See [docs/deployment-procedure.md](docs/deployment-procedure.md) for the
full walkthrough.

## Layout

- `terraform/` — clones `vm-template-name` via the Proxmox API, outputs the
  new VM's IPv4 address (via the QEMU guest agent)
- `ansible/` — configures the VM over SSH as `fabricator`:
  - `base` — package updates, base packages
  - `docker-ce` — Docker's official RHEL repo, `docker-ce` +
    `docker-ce-cli` + `containerd.io` + buildx/compose plugins, enables
    the `docker` service, adds `fabricator` to the `docker` group
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

`.gitlab-ci.yml` here (included from the repo root) runs `validate`
automatically and gates `plan`/`apply`/`configure`/`destroy` as manual
jobs. See "Running via GitLab CI/CD" in
[docs/deployment-procedure.md](docs/deployment-procedure.md) for the
required CI/CD variables.
