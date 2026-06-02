# Makefile for IDP Lab Ansible automation

# Load .env file if it exists
ifneq (,$(wildcard .env))
  include .env
  export
endif

# Playbook path
PLAYBOOK = playbooks/idp_lab_from0.yml

# Extra variables to pass to ansible-playbook (e.g. EXTRA_VARS="-e key=value")
EXTRA_VARS ?=

# Build -e flags from .env variables (only when set)
ENV_VARS :=
ifdef COMMON_PASSWORD
  ENV_VARS += -e common_password=$(COMMON_PASSWORD)
endif

.PHONY: help deploy clean gitlab-reset showroom showroom-restart keycloak-config

help:
	@echo ""
	@echo "IDP Lab — Ansible targets"
	@echo ""
	@echo "  make deploy        Run the full idp_lab_from0 role (GitOps → NooBaa → Vault → GitLab → Showroom)"
	@echo "  make gitops        Deploy OpenShift GitOps only"
	@echo "  make noobaa        Deploy NooBaa only"
	@echo "  make vault         Deploy Vault only"
	@echo "  make gitlab        Deploy GitLab only (requires vault namespace to exist)"
	@echo "  make keycloak-config  Create Keycloak admin user in master realm"
	@echo "  make gitlab-reset  Delete and re-seed GitLab repos without reinstalling GitLab"
	@echo "  make showroom      Deploy Showroom only"
	@echo "  make showroom-restart  Force a rollout of the Showroom deployment (rebuild content)"
	@echo "  make clean         Delete all deployed resources from the cluster"
	@echo ""
	@echo "Optional .env or environment variables:"
	@echo "  COMMON_PASSWORD      Shared password for lab users and services"
	@echo ""

deploy:
	@start=$$(date); \
	ansible-playbook $(PLAYBOOK) $(ENV_VARS) $(EXTRA_VARS); \
	end=$$(date); \
	echo "Start at $$start"; \
	echo "End   at $$end"

gitops:
	ansible-playbook $(PLAYBOOK) --tags install_gitops $(ENV_VARS) $(EXTRA_VARS)

gitlab:
	ansible-playbook $(PLAYBOOK) --tags install_gitlab $(ENV_VARS) $(EXTRA_VARS)

noobaa:
	ansible-playbook $(PLAYBOOK) --tags install_noobaa $(ENV_VARS) $(EXTRA_VARS)

vault:
	ansible-playbook $(PLAYBOOK) --tags install_vault $(ENV_VARS) $(EXTRA_VARS)

showroom:
	ansible-playbook $(PLAYBOOK) --tags install_showroom $(ENV_VARS) $(EXTRA_VARS)

keycloak-config:
	ansible-playbook $(PLAYBOOK) --tags keycloak_config $(ENV_VARS) $(EXTRA_VARS)

gitlab-rhdh-group:
	ansible-playbook $(PLAYBOOK) --tags gitlab_rhdh_group $(ENV_VARS) $(EXTRA_VARS)

gitlab-reset-repos:
	ansible-playbook $(PLAYBOOK) --tags gitlab_reset $(ENV_VARS) $(EXTRA_VARS)

showroom-restart:
	oc rollout restart deployment/showroom -n showroom
	oc rollout status deployment/showroom -n showroom

clean:
	./clean.sh
