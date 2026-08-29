# Proxmox VM template best practices

Review of the two template configs in
[instructions/instruction-03.txt](../instructions/instruction-03.txt)
(VMID 163 `vm-oracle10`, VMID 161 `vm-alma10`), against the stated
conditions — XFS inside the guest, storage as qcow2 or raw on a ZFS RAID10
pool — plus a reference config for the new Windows variant. This is advice
only: nothing here touches your Proxmox host or its templates.

## Findings on the two Linux configs

| # | Finding | Config(s) | Severity |
|---|---|---|---|
| 1 | `vm-alma10` (161) has no `template: 1` — it is still a regular VM, not a template. `qm template 161` needs to be run before Terraform can clone it. | 161 | **Blocker** |
| 2 | `vm-alma10`'s disk is on `local-lvm` (LVM-thin), not the ZFS pool at all. Only `vm-oracle10` (163, on `vm-directory`, a qcow2-on-ZFS-dataset storage) is even close to the stated "qcow2 or raw on ZFS RAID10" condition. | 161 | **Blocker** (contradicts the stated storage requirement) |
| 3 | qcow2-on-a-ZFS-directory-dataset stacks two copy-on-write layers (qcow2's own COW over ZFS's COW). This roughly doubles write amplification and metadata overhead, and moves snapshots to file-level (qcow2) instead of ZFS-native. On a ZFS pool, prefer Proxmox's native `zfspool` storage type with `raw` disks (zvols) — snapshots, compression and checksums then come from ZFS itself, and Proxmox's own snapshot feature becomes a native (near-instant) ZFS snapshot instead of a qcow2 file copy. | 163 | Recommended change |
| 4 | XFS + Docker: `vm-docker-regular` needs `overlay2`, which requires XFS created with `ftype=1` (d_type support). `mkfs.xfs` has defaulted to `ftype=1` since RHEL/CentOS 7.4, so a fresh Rocky/Alma/Oracle 10 install should already be fine — but this is a hard requirement, not a nice-to-have, so it's worth an explicit `xfs_info / \| grep ftype` check on the template before relying on it. | both | Verify |
| 5 | `boot: order=scsi0;net0` still includes a PXE/network boot fallback that a finished template will never use; `vm-oracle10`'s `boot: order=scsi0` is the cleaner form. | 161 | Cosmetic |
| 6 | `pre-enrolled-keys=1` (Secure Boot with Microsoft + distro keys) is good practice and works out of the box with RHEL-family's signed shim/GRUB/kernel — Rocky/Alma/Oracle 10 all support it. It only becomes a problem if an unsigned out-of-tree kernel module gets installed later (e.g. a DKMS driver) without MOK-enrolling its key. Not an issue for anything currently in this repo's Ansible roles. | both | Informational |
| 7 | `cpu: host` gives the guest the host's exact CPU model — best performance, but blocks live migration to a Proxmox node with a different CPU model. Fine for a single-node deployment (matches this repo's single `pve_node` variable); if these templates ever run on a multi-node cluster with mixed CPU generations, switch to a baseline type like `x86-64-v2-AES` instead. | both | Informational |
| 8 | No `tags:` set. Not required, but tagging templates (e.g. `template;linux;rocky10`) pays off once there are several of them in the same PVE UI. | both | Nice-to-have |
| 9 | Neither config attaches a serial console (`serial0: socket` + `vga: serial0`). Not required — SSH is the real access path — but it's a useful out-of-band fallback for a headless Linux template when SSH itself is broken (e.g. mid-generalization). | both | Nice-to-have |
| 10 | No cloud-init drive is present on either template. This repo's Terraform (`initialization { ip_config { ipv4 { address = "dhcp" } } }` in `main.tf`) only takes effect if cloud-init is installed in the guest; if it isn't, that block is harmless but inert, and the VM's network still comes up via whatever the OS's own NetworkManager profile does (DHCP by default on a stock RHEL-family install). Worth confirming which of the two is actually true for these templates so the Terraform config matches reality. | both | Verify |

**Everything else lines up with best practice already**: `agent: 1` (required for the IP-discovery output in `terraform/outputs.tf`), `discard=on` + `ssd=1` (TRIM passthrough), `iothread=1` paired with `scsihw: virtio-scsi-single` (per-disk I/O thread — needs that specific controller), `bios: ovmf` + `machine: q35` + `efitype=4m` (modern UEFI, correct vars-disk size for Secure Boot state), and `balloon: 0` (predictable memory for a service VM, avoids double memory-management with `qemu-guest-agent` already handling reporting).

### Reference Linux template config (ZFS RAID10, raw zvol, XFS guest)

```
agent: 1
balloon: 0
bios: ovmf
boot: order=scsi0
cores: 4
cpu: host
efidisk0: <zfspool-storage-id>:vm-<id>-disk-0,efitype=4m,pre-enrolled-keys=1,size=4M
machine: q35
memory: 4096
name: vm-rocky10
net0: virtio=<mac>,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsi0: <zfspool-storage-id>:vm-<id>-disk-1,discard=on,iothread=1,size=64G,ssd=1
scsihw: virtio-scsi-single
serial0: socket
sockets: 1
tags: template;linux;rocky10
vga: serial0
```

`<zfspool-storage-id>` is a Proxmox storage of type `zfspool` pointing at the
RAID10 pool (`Datacenter > Storage > Add > ZFS`), not a directory storage
holding qcow2 files. Pool-level settings worth confirming at creation time
(not part of `qm config`): `ashift` matching the physical drives' sector
size (usually 12), and `compression=lz4` (or `zstd`) on the dataset —
both are cheap and generally a net win.

## Windows on Proxmox: best practices + reference config

Same storage guidance applies (native `zfspool` + `raw` over qcow2-on-ZFS),
plus Windows-specific requirements:

- **NTFS vs ReFS**: Windows cannot boot from ReFS — the system/boot volume
  must be NTFS. ReFS is only valid for a *secondary data volume*, not `C:\`.
  If ReFS is wanted anywhere, it has to be an extra disk, not the OS disk.
- **TPM**: Windows 11 and Server 2022+ require a TPM 2.0 device to install
  and (for 11) to boot at all. Proxmox provides this as a `tpmstate0` disk
  — without it, a Windows 11/Server 2022+ template can't be built or will
  refuse to boot after certain updates.
- **`ostype`**: use `win11` for Windows 11 / Server 2022+/2025 guests,
  `win10` for Server 2016/2019 or Windows 10 — this tunes QEMU's Hyper-V
  enlightenment flags (time sync, TLB flush, etc.) automatically; nothing
  extra to configure.
- **VirtIO drivers**: unlike Linux, Windows has no built-in virtio drivers.
  The `virtio-scsi-single` disk controller and `virtio` NIC both need the
  `vioscsi`/`netkvm` drivers from the [virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts)
  ISO loaded during install (Windows Setup won't even see the disk
  otherwise), and `qemu-guest-agent` needs the matching `qemu-ga-x86_64.msi`
  installed as a Windows service — required for this repo's Terraform to
  read back the VM's IPv4 the same way it does for Linux.
- **Discard/TRIM**: `discard=on` + `ssd=1` still apply, but Windows only
  issues TRIM if it isn't disabled — confirm
  `fsutil behavior query DisableDeleteNotify` returns `0` on the template.
- **Cloud-init**: Proxmox's built-in cloud-init does not configure Windows
  guests (no Cloudbase-Init integration out of the box). `vm-windows-regular`
  therefore skips the `initialization` block entirely and relies on the
  guest's own DHCP-enabled NIC; add Cloudbase-Init to the template and an
  `initialization` block to `main.tf` later if that's ever needed.

### Reference Windows template config (ZFS RAID10, raw zvol, NTFS guest)

```
agent: 1
balloon: 0
bios: ovmf
boot: order=scsi0
cores: 4
cpu: host
efidisk0: <zfspool-storage-id>:vm-<id>-disk-0,efitype=4m,pre-enrolled-keys=1,size=4M
machine: q35
memory: 8192
name: vm-win2022
net0: virtio=<mac>,bridge=vmbr0,firewall=1
numa: 0
ostype: win11
scsi0: <zfspool-storage-id>:vm-<id>-disk-1,discard=on,iothread=1,size=80G,ssd=1
scsihw: virtio-scsi-single
sockets: 1
tags: template;windows;win2022
tpmstate0: <zfspool-storage-id>:vm-<id>-disk-2,version=v2.0
```
