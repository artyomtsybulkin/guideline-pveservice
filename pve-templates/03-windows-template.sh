#!/usr/bin/env bash
# Builds the Windows VM shell — hardware only, plus attaching install
# media. The OS install itself is an interactive GUI step you do over the
# console: a licensed Windows ISO install can't be scripted like a cloud
# image import. Run on the Proxmox host as root.
#
# The Proxmox host is not assumed to have internet access, so this script
# does not download anything. Both ISOs must already be uploaded to Proxmox
# storage (Datacenter > Storage > ... > ISO Images, or `pvesm` yourself)
# before running this:
#   - WINDOWS_ISO: volid of your licensed Windows install ISO,
#     e.g. "local:iso/windows2025.iso".
#   - VIRTIO_WIN_ISO: volid of the virtio-win drivers ISO (vioscsi, netkvm,
#     qemu-ga) — get it from
#     https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
#     on a machine with internet access and upload it the same way,
#     e.g. "local:iso/virtio-win.iso".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_root

VMID="${VMID:-9003}"
VM_NAME="${VM_NAME:-vm-win2025}"
OSTYPE="${OSTYPE:-win11}"   # win11 for Server 2022+/2025 and Windows 10/11; win10 for Server 2016/2019
DISK_SIZE_GB="${DISK_SIZE_GB:-60}"
WINDOWS_ISO="${WINDOWS_ISO:-local:iso/windows2025.iso}"
VIRTIO_WIN_ISO="${VIRTIO_WIN_ISO:-local:iso/virtio-win.iso}"

require_vmid_free "$VMID"

echo "==> creating VM $VMID ($VM_NAME)"
qm create "$VMID" \
  --name "$VM_NAME" \
  --machine q35 \
  --bios ovmf \
  --cpu host \
  --sockets 1 \
  --cores 4 \
  --memory 8192 \
  --balloon 0 \
  --numa 0 \
  --net0 "virtio,bridge=${PVE_BRIDGE}" \
  --scsihw virtio-scsi-single \
  --ostype "$OSTYPE" \
  --agent enabled=1
qm set "$VMID" --efidisk0 "${PVE_STORAGE}:1,efitype=4m,pre-enrolled-keys=1"
qm set "$VMID" --tpmstate0 "${PVE_STORAGE}:1,version=v2.0"

echo "==> creating the system disk (${DISK_SIZE_GB}G, empty — Windows Setup partitions it)"
qm set "$VMID" --scsi0 "${PVE_STORAGE}:${DISK_SIZE_GB},discard=on,iothread=1,ssd=1"

echo "==> attaching install media"
qm set "$VMID" --ide2 "${WINDOWS_ISO},media=cdrom"
qm set "$VMID" --ide3 "${VIRTIO_WIN_ISO},media=cdrom"
qm set "$VMID" --boot "order=ide2;scsi0"

cat <<EOF

VM $VMID is ready for a manual install. This part is not scriptable:

  1. Open this VM's console in the Proxmox web UI and start it
     (or: qm start $VMID).
  2. Run Windows Setup as usual. When it doesn't see the system disk,
     click "Load driver" and browse the virtio-win CD for vioscsi
     (\\<version>\\<Windows version>\\amd64) — needed because Windows has
     no built-in virtio driver.
  3. After install, from within Windows run the virtio-win CD's
     virtio-win-guest-tools.exe (installs netkvm + the rest) and install
     qemu-ga (also on that CD) as a service — Terraform's IP-discovery
     depends on it, same as the Linux templates.
  4. Configure whatever access this template should ship with (RDP,
     local Administrator password, WinRM if you're adding an Ansible/
     WinRM half later — see vm-windows-regular/docs/deployment-procedure.md).
  5. Generalize it — Windows' equivalent of this repo's Linux first-boot
     role, so every clone gets a unique SID/identity:
       %WINDIR%\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /mode:vm
     Sysprep shuts the VM down itself; wait for that shutdown rather than
     shutting it down manually mid-sysprep.

EOF
read -r -p "Press Enter once sysprep has shut the VM down and it's ready to finalize... "

while qm status "$VMID" | grep -q running; do sleep 5; done

echo "==> detaching install media"
qm set "$VMID" --delete ide2 --delete ide3
qm set "$VMID" --boot order=scsi0

echo "==> converting to a template"
qm template "$VMID"

echo "==> done: VMID $VMID ($VM_NAME) is now a template"
