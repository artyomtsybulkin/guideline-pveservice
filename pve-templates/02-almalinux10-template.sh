#!/usr/bin/env bash
# Builds the AlmaLinux 10 template — hardware only, plus attaching the
# installer ISO. The OS install itself (Anaconda) is an interactive step
# you do over the console: there's no cloud image here to script an
# import from, just a real installer ISO. Run on the Proxmox host as root.
#
# Requires OS_ISO already uploaded to Proxmox storage (Datacenter >
# Storage > ... > ISO Images, or `pvesm`) — point it at the volid,
# e.g. "local:iso/almalinux10.iso". The Proxmox host is not assumed to
# have internet access, so this script does not download anything.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_root

VMID="${VMID:-9002}"
VM_NAME="${VM_NAME:-vm-alma10}"
DISK_SIZE_GB="${DISK_SIZE_GB:-20}"
OS_ISO="${OS_ISO:-local:iso/almalinux10.iso}"
FABRICATOR_PUBKEY_FILE="${FABRICATOR_PUBKEY_FILE:?Set FABRICATOR_PUBKEY_FILE to the path of the fabricator public key to bake into the image}"

require_vmid_free "$VMID"
if [[ ! -f "$FABRICATOR_PUBKEY_FILE" ]]; then
  echo "FABRICATOR_PUBKEY_FILE does not exist: $FABRICATOR_PUBKEY_FILE" >&2
  exit 1
fi

echo "==> creating VM $VMID ($VM_NAME)"
qm create "$VMID" \
  --name "$VM_NAME" \
  --machine q35 \
  --bios ovmf \
  --cpu host \
  --sockets 1 \
  --cores 4 \
  --memory 4096 \
  --balloon 0 \
  --numa 0 \
  --net0 "virtio,bridge=${PVE_BRIDGE}" \
  --scsihw virtio-scsi-single \
  --ostype l26 \
  --agent enabled=1
qm set "$VMID" --efidisk0 "${PVE_STORAGE}:1,efitype=4m,pre-enrolled-keys=1"

echo "==> creating the system disk (${DISK_SIZE_GB}G, empty — the installer partitions it)"
qm set "$VMID" --scsi0 "${PVE_STORAGE}:${DISK_SIZE_GB},discard=on,iothread=1,ssd=1"

echo "==> attaching install media"
qm set "$VMID" --ide2 "${OS_ISO},media=cdrom"
qm set "$VMID" --boot "order=ide2;scsi0"

cat <<EOF

VM $VMID is ready for a manual install. This part is not scriptable:

  1. Open this VM's console in the Proxmox web UI and start it
     (or: qm start $VMID).
  2. Run through the Anaconda installer as usual. XFS is Anaconda's
     default root filesystem on AlmaLinux 10 — no need to change it.
     Make sure networking is enabled (DHCP) so the next step can reach
     the network.
  3. After install and first boot, log in over the console as root and
     run, to create fabricator with passwordless sudo (needed for
     Ansible's become: true) and its SSH key, plus the guest agent
     (Terraform's IP-discovery depends on it, before Ansible ever
     connects):

       useradd -m -G wheel fabricator
       install -d -m 700 -o fabricator -g fabricator /home/fabricator/.ssh
       cat > /home/fabricator/.ssh/authorized_keys <<'KEY'
$(cat "$FABRICATOR_PUBKEY_FILE")
KEY
       chmod 600 /home/fabricator/.ssh/authorized_keys
       chown fabricator:fabricator /home/fabricator/.ssh/authorized_keys
       echo 'fabricator ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/fabricator
       chmod 440 /etc/sudoers.d/fabricator
       dnf install -y qemu-guest-agent
       systemctl enable --now qemu-guest-agent

  4. Shut the VM down (poweroff, or: qm shutdown $VMID).

EOF
read -r -p "Press Enter once the VM has shut down and it's ready to finalize... "

while qm status "$VMID" | grep -q running; do sleep 5; done

echo "==> detaching install media"
qm set "$VMID" --delete ide2
qm set "$VMID" --boot order=scsi0

echo "==> converting to a template"
qm template "$VMID"

echo "==> done: VMID $VMID ($VM_NAME) is now a template"
