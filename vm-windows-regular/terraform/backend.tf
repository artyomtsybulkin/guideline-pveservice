# Declares GitLab's managed Terraform state as the backend so state is
# never left on a CI runner's disk. Left empty here on purpose — the actual
# address/credentials are supplied at `terraform init` time via
# -backend-config (see ../scripts/tf-init.sh, used by both deploy.sh and
# ../.gitlab-ci.yml).
terraform {
  backend "http" {}
}
