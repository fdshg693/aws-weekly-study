ENV ?= dev

TFVARS_dev := dev.tfvars
TFVARS_prod := prod.tfvars
TFVARS := $(TFVARS_$(ENV))

.PHONY: check-env help init fmt validate plan apply destroy output test

check-env:
	@if [ -z "$(TFVARS)" ]; then \
		echo "ENV must be dev or prod"; \
		exit 1; \
	fi

help:
	@echo "Usage: make <target> ENV=dev|prod"
	@echo ""
	@echo "Targets:"
	@echo "  init      Terraform init"
	@echo "  fmt       Terraform fmt -recursive"
	@echo "  validate  Terraform validate"
	@echo "  plan      Terraform plan with environment tfvars"
	@echo "  apply     Terraform apply with environment tfvars"
	@echo "  destroy   Terraform destroy with environment tfvars"
	@echo "  output    Show Terraform outputs"
	@echo "  test      Test deployed API Gateway endpoint"

init: check-env
	terraform init

fmt:
	terraform fmt -recursive

validate: check-env fmt
	terraform validate

plan: check-env
	terraform plan -var-file=$(TFVARS)

apply: check-env
	terraform apply -var-file=$(TFVARS)

destroy: check-env
	terraform destroy -var-file=$(TFVARS)

output:
	terraform output

test: check-env
	./test_api.sh $(ENV)