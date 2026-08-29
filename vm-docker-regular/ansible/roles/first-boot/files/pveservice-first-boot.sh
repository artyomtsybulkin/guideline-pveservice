#!/usr/bin/env bash
# Regenerates per-VM identifiers that vm-template-name's clones would
# otherwise all share (machine-id, SSH host keys), plus general cleanup.
# Runs exactly once, via pveservice-first-boot.service. See
# instructions/instruction-02.txt for the source script.
set -euo pipefail

dnf autoremove -y
dnf clean all
dnf update -y

truncate -s 0 /etc/machine-id
rm -f /etc/machine-id
systemd-machine-id-setup

rm -f /etc/ssh/ssh_host_*

journalctl --rotate
journalctl --vacuum-time=1s
rm -rf /var/log/*

history -c
rm -rf /home/*/.bash_history

fstrim -av
