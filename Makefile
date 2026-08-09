SHELL := /bin/bash

.DEFAULT_GOAL := help

RED    := \033[1;31m
YELLOW := \033[1;33m
GREEN  := \033[1;32m
CYAN   := \033[1;36m
RESET  := \033[0m

# ------------------------------------------------------------------------------
# Global settings
# ------------------------------------------------------------------------------

# TF_ENV selects which environment directory to operate on.
# We default to "dev" because that's your first playground.
TF_ENV ?= dev


# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
.PHONY: help
help: ## Show all available targets with short descriptions.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target> [TF_ENV=dev|staging|prod]\n\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ { printf "  %-40s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# -----------------------------------------------------------------------------------
# Cluster setup
# -----------------------------------------------------------------------------------
.PHONY: setup-minikube
setup-minikube: ## Ensure Minikube cluster is running with correct profile.
	@echo -e "$(CYAN) Ensure Minikube cluster is running with correct profile $(RESET)"; \
	$(MAKE) -f Makefile_Setup ensure-minikube; \
	$(MAKE) -f Makefile_Setup enable-minikube-addons; \
	$(MAKE) -f Makefile_Setup check-clusterinfo; \
	$(MAKE) -f Makefile_Setup kubectl-get-nodes

.PHONY: setup-terraform
setup-terraform: ## 
	@printf '$(CYAN) %s $(RESET) \n' \
		' What will we do to setup Terraform: ' \
		' 		- Step 1. Install latest Terraform' \
		' 		- Step 2. Verify Terraform installed'; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_Setup tf-ensure-installed

.PHONY: login-into-hcp-terraform 
login-into-hcp-terraform: setup-terraform ## Run 'terraform login' to authorize CLI with HCP Terraform.
	@printf '$(CYAN) %s $(RESET) \n' \
		' Login into HCP Terraform using terraform login ' \
		' 	- It will authorize CLI with HCP Terraform ' \
		' 	- Opens a browser or prints a URL to authorize your CLI against HCP Terraform. ' \
		' 	- It will Saves the API token to `~/.terraform.d/credentials.tfrc.json` '; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-login-cloud	

.PHONY: tf-workflow-with-hcp-terraform-as-remote-backend-for-state-init-plan-apply-verify-destroy
tf-workflow-with-hcp-terraform-as-remote-backend-for-state-init-plan-apply-verify-destroy: login-into-hcp-terraform ## Run init, fmt, validate, and plan for the selected environment.
	@printf '$(CYAN)%s$(RESET)\n' \
		'Verifying Terraform workflow with HCP Terraform as the backend for remote state for $(TF_ENV)...' \
		'Step A. Clean Everything (remove previous runs outputs)' ; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-clean-force

# 	@printf '$(CYAN) %s $(RESET) \n' \
# 		'Step B. What will we do to setup Terraform: ' \
# 		' 		- Create a namespace outside Terraform, we use  importable resource like kubernetes' \
# 		' 		- make sure cluster (minikube) is running'; \
# 	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
# 	read -r _
# 	kubectl create namespace import-lab || true
# 	kubectl get namespace import-lab

	@printf '$(CYAN) %s $(RESET) \n' \
		'Step C. Formatting Terraform files... '; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-fmt

	@printf '$(CYAN) %s $(RESET) \n' \
		'Step D. Initialize Terraform in the selected environment. '; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _	
	$(MAKE) -f Makefile_HCP_TR tf-init

	@printf '$(CYAN) %s $(RESET) \n' \
		'Step E. Validate the selected environme nt configuration.'; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-validate

# 	# Import the namespace
# 	@printf '$(CYAN) %s $(RESET) \n' \
# 		'Step G. Import the namespace'; \
# 	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
# 	read -r _
# # 	cd $(TF_DIR)  && terraform import kubernetes_namespace.imported import-lab || true
# 	$(MAKE) -f Makefile_HCP_TR tf-import \
# 		TF_ENV=dev \
# 		IMPORT_ADDRESS=kubernetes_namespace.imported \
# 		IMPORT_ID="import-lab"|| true

	@printf '$(CYAN) %s $(RESET) \n' \
		'Step H. Plan the selected environment using terraform.tfvars.'; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-plan

	@printf '$(CYAN) %s $(RESET) \n' \
		'Step I. Apply the selected environment using terraform.tfvars.'; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-apply

	@printf '$(CYAN) %s $(RESET) \n' \
		'Step J. Verify expected Terraform outputs' \
		' 		 Verify expected Terraform state resources'; \
	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
	read -r _
	$(MAKE) -f Makefile_HCP_TR tf-verify-post-apply

# 	@printf '$(CYAN) %s $(RESET) \n' \
# 		'Step K. Destroy the selected environment using terraform.tfvars.'; \
# 	printf '$(CYAN) %s $(RESET) \n' "Press ENTER to continue..."; \
# 	read -r _
# 	$(MAKE) -f Makefile_HCP_TR tf-destroy







## Donot call tf-clean and tf-destroy
.PHONY: tf-check-stateinspection-update-drift-import
tf-check-stateinspection-update-drift-import:
	@printf '$(CYAN)%s$(RESET)\n' "Check State inspection, update, drift and import $(TF_ENV)..."
	$(MAKE) -f Makefile_TR_Workflow tf-fmt
	$(MAKE) -f Makefile_TR_Workflow tf-init
	$(MAKE) -f Makefile_TR_Workflow tf-validate
	$(MAKE) -f Makefile_TR_Workflow tf-plan

	$(MAKE) -f Makefile_TR_Workflow tf-apply
	$(MAKE) -f Makefile_TR_Workflow tf-verify-post-apply

	$(MAKE) -f Makefile_TR_Workflow tf-automated-stateinspection-update-drift-import

.PHONY: tf-run-recommended-order-to-detect-changes
tf-run-recommended-order-to-detect-changes:
	$(MAKE) -f Makefile_TR_Workflow tf-run-recommended-order-to-detect-and-record-the-changes	

.PHONY: tf-stateinspection-update-drift-import
tf-stateinspection-update-drift-import: ## Automate state inspection, update, drift, and import exercises.
	@printf '$(CYAN)%s$(RESET)\n' "Running automated Terraform Phase 2 for $(TF_ENV)..."
	./scripts/terraform-phase2.sh
	@printf '$(GREEN)%s$(RESET)\n' "Automated Terraform Phase 2 completed."


# Example: safe usage pattern
# Start from a clean shell.
# Run:
# bash
# make setup-minikube
# This ensures k8s-learning profile is up and configured.

# Then run:
# bash
# make setup-terraform

