#!/usr/bin/env bash
# Shared `terraform init`: points at GitLab's managed Terraform state so
# local runs and CI runs read/write the same state. In CI, CI_API_V4_URL,
# CI_PROJECT_ID and CI_JOB_TOKEN are already set by GitLab; for local runs
# export CI_API_V4_URL, CI_PROJECT_ID and GITLAB_TOKEN (a personal/project
# access token with the `api` scope) yourself.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/terraform"

: "${CI_API_V4_URL:?Set CI_API_V4_URL, e.g. https://gitlab.example.com/api/v4}"
: "${CI_PROJECT_ID:?Set CI_PROJECT_ID (Project ID, found on the Settings > General page)}"
TF_STATE_NAME="${TF_STATE_NAME:-vm-windows-regular}"
TF_USERNAME="${TF_USERNAME:-gitlab-ci-token}"
TF_PASSWORD="${TF_PASSWORD:-${CI_JOB_TOKEN:-${GITLAB_TOKEN:-}}}"
: "${TF_PASSWORD:?Set CI_JOB_TOKEN (set automatically in CI) or GITLAB_TOKEN (locally)}"

TF_ADDRESS="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/${TF_STATE_NAME}"

terraform -chdir="$TF_DIR" init -input=false \
  -backend-config="address=${TF_ADDRESS}" \
  -backend-config="lock_address=${TF_ADDRESS}/lock" \
  -backend-config="unlock_address=${TF_ADDRESS}/lock" \
  -backend-config="username=${TF_USERNAME}" \
  -backend-config="password=${TF_PASSWORD}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
