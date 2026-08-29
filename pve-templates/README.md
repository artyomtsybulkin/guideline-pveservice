# pve-templates

Scripts to build the three VM templates this repo's Terraform clones from
(`vm_template_name`) — run **on the Proxmox host itself**, as root; these
are not part of the Terraform/Ansible automation, which assumes the
templates already exist. See
[../docs/proxmox-template-best-practices.md](../docs/proxmox-template-best-practices.md)
for the reasoning (storage, filesystem, UEFI/TPM) behind the choices below.

| Script | Produces | Installer ISO |
|---|---|---|
| `01-oraclelinux10-template.sh` | `vm-oracle10` | `oraclelinux10.iso` |
| `02-almalinux10-template.sh` | `vm-alma10` | `almalinux10.iso` |
| `03-windows-template.sh` | `vm-win2025` | `windows2025.iso` (+ `virtio-win.iso`) |

All three follow the same pattern, since all three start from a real
installer ISO rather than a scriptable cloud image: build the VM's
hardware, attach the ISO, then pause for you to do the actual OS install
interactively over the Proxmox console (Anaconda for the Linux two,
Windows Setup for the third) — not something `qm` can drive. Once you
confirm the VM has shut down, each script detaches the install media and
finalizes the template (`qm template`).

None of these scripts download anything — the Proxmox host is not assumed
to have internet access. Every ISO must already be uploaded to Proxmox
storage (Datacenter > Storage > ... > ISO Images, or `pvesm`) before
running the matching script.

All three: `bios=ovmf` + `machine=q35` (UEFI, Secure Boot with
pre-enrolled keys), `scsihw=virtio-scsi-single` with `discard=on` +
`ssd=1` on the system disk, `agent=1` (required for this repo's
Terraform to read back the VM's IPv4), and storage/network defaults
(`vm-directory`, `vmbr0` untagged) matching `vm-*-regular/terraform`'s own
defaults. Override either via `PVE_STORAGE=... PVE_BRIDGE=... ./01-...sh`.
The system disk is created empty and deliberately small (20G Linux / 60G
Windows) — `vm-*-regular`'s Terraform resizes it up to the deployed VM's
actual size (64G / 128G) on clone, same as a real full clone always would.

## Linux templates (Oracle Linux 10, AlmaLinux 10)

```sh
OS_ISO=local:iso/oraclelinux10.iso \
FABRICATOR_PUBKEY_FILE=/root/fabricator.pub \
  ./01-oraclelinux10-template.sh

OS_ISO=local:iso/almalinux10.iso \
FABRICATOR_PUBKEY_FILE=/root/fabricator.pub \
  ./02-almalinux10-template.sh
```

Each script creates the VM, attaches `oraclelinux10.iso`/`almalinux10.iso`,
then pauses with on-screen instructions for the interactive Anaconda
install (XFS is Anaconda's default root filesystem — nothing to change)
and a ready-to-paste post-install command block that:
- creates `fabricator` with the public key from `FABRICATOR_PUBKEY_FILE`
  baked directly into the printed instructions,
- grants it **passwordless sudo** (`/etc/sudoers.d/fabricator`) — required
  for Ansible's `become: true`, since nothing else will have set a
  password for it,
- installs and enables `qemu-guest-agent` — this has to be in the
  template already, since Terraform reads the cloned VM's IP via the
  guest agent *before* Ansible ever gets a chance to connect and install
  anything itself.

Once you confirm the VM is shut down, the script detaches the ISO and
converts it to a template.

## Windows template

```sh
WINDOWS_ISO=local:iso/windows2025.iso \
VIRTIO_WIN_ISO=local:iso/virtio-win.iso \
  ./03-windows-template.sh
```

Requires both ISOs already uploaded: your licensed Windows install ISO
(`windows2025.iso`) and the virtio-win drivers ISO (vioscsi, netkvm,
qemu-ga) — download the latter yourself from
https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
on a machine with internet access and upload it the same way.

The script creates the VM (including the `tpmstate0` TPM 2.0 device
Windows 11/Server 2022+ requires) and attaches both ISOs, then pauses:
Windows Setup + loading the `vioscsi` driver + `sysprep /generalize` is an
interactive step you do over the Proxmox console. Once sysprep has shut
the VM down, pressing Enter finishes the job (detach media, convert to
template). See `../vm-windows-regular/docs/deployment-procedure.md` for
what the resulting template needs (`qemu-guest-agent`, virtio drivers)
and why there's no Ansible/WinRM half yet.

## After building a template

Point the matching variant's `terraform.tfvars` (or `TF_VAR_vm_template_name`
in CI) at the template's name (`vm-oracle10`, `vm-alma10`, or
`vm-win2025`), then deploy as normal — see each `vm-*-regular/README.md`.
