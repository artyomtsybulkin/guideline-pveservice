#!/usr/bin/env bash
# Fetches the fabricator private key from a secret store and writes it to a
# temp file with 0600 permissions. Prints the file path on stdout.
#
# Backend is selected via SECRET_BACKEND: vault | aws | local | gitlab (default: vault).
# Add a case for whatever secret store you actually run.
set -euo pipefail

SECRET_BACKEND="${SECRET_BACKEND:-vault}"
KEY_PATH="$(mktemp)"
chmod 600 "$KEY_PATH"

case "$SECRET_BACKEND" in
  vault)
    : "${VAULT_SECRET_PATH:?Set VAULT_SECRET_PATH, e.g. secret/data/pve/fabricator}"
    vault kv get -field=private_key "$VAULT_SECRET_PATH" > "$KEY_PATH"
    ;;
  aws)
    : "${AWS_SECRET_ID:?Set AWS_SECRET_ID, e.g. pve/fabricator-private-key}"
    aws secretsmanager get-secret-value --secret-id "$AWS_SECRET_ID" \
      --query SecretString --output text > "$KEY_PATH"
    ;;
  local)
    # Dev-only fallback: read from a path already on disk.
    : "${FABRICATOR_PRIVATE_KEY_FILE:?Set FABRICATOR_PRIVATE_KEY_FILE for the local backend}"
    cp "$FABRICATOR_PRIVATE_KEY_FILE" "$KEY_PATH"
    ;;
  gitlab)
    # CI: read from a masked+protected GitLab CI/CD variable. Prefer GitLab's
    # native Vault/AWS `secrets:` keyword instead where available — it never
    # stores the key as a plain CI variable.
    : "${FABRICATOR_PRIVATE_KEY:?Set FABRICATOR_PRIVATE_KEY as a masked, protected CI/CD variable}"
    printf '%s\n' "$FABRICATOR_PRIVATE_KEY" > "$KEY_PATH"
    ;;
  *)
    echo "Unknown SECRET_BACKEND: $SECRET_BACKEND" >&2
    exit 1
    ;;
esac

echo "$KEY_PATH"
