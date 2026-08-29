# vm-windows-regular

Terraform + GitLab CI only, for now: clones a Windows VM from a
pre-existing template. No Ansible/WinRM configuration step yet — see
[docs/deployment-procedure.md](docs/deployment-procedure.md) for how to add
one later.

Template requirements: `qemu-guest-agent` (Windows service) and the
virtio-win drivers already installed. See
[../docs/proxmox-template-best-practices.md](../docs/proxmox-template-best-practices.md)
for the full Windows-on-Proxmox review (TPM, ostype, NTFS vs ReFS, storage).

## Layout

- `terraform/` — clones `vm_template_name` via the Proxmox API, outputs the
  new VM's IPv4 address (via the QEMU guest agent)
- `scripts/deploy.sh` — terraform apply, prints the IP
- `scripts/destroy.sh` — tears the VM down

## Quick start

```sh
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# fill in terraform.tfvars with your Proxmox endpoint/token/node

./scripts/deploy.sh
```

## GitLab CI/CD

`.gitlab-ci.yml` here (included from the repo root) runs `validate`
automatically and gates `plan`/`apply`/`destroy` as manual jobs. See
"Running via GitLab CI/CD" in
[docs/deployment-procedure.md](docs/deployment-procedure.md) for the
required CI/CD variables.
