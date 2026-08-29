# Local shortcuts around the terraform/ansible commands; CI calls the same
# scripts directly from .gitlab-ci.yml instead of this file.
.PHONY: init plan apply deploy destroy fmt

init:
	./scripts/tf-init.sh

plan:
	terraform -chdir=terraform plan

apply:
	terraform -chdir=terraform apply

deploy:
	./scripts/deploy.sh

destroy:
	./scripts/destroy.sh

fmt:
	terraform -chdir=terraform fmt -recursive
