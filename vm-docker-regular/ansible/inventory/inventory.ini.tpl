# Rendered by scripts/deploy.sh from Terraform's vm_ipv4_address output and
# the private key path returned by scripts/fetch-secret.sh. Do not edit the
# generated inventory.ini by hand — it is a build artifact.
[pve_service]
__VM_IPV4__ ansible_user=fabricator ansible_ssh_private_key_file=__FABRICATOR_PRIVATE_KEY_PATH__
