.DEFAULT_GOAL := deploy

COMPONENT_NAME ?= stack-k8s-eks
DOMAIN_NAME    ?= eks-1.dev.superhub.io
NAME           := $(shell echo $(DOMAIN_NAME) | cut -d. -f1)
BASE_DOMAIN    := $(shell echo $(DOMAIN_NAME) | cut -d. -f2-)
NAME2          := $(shell echo $(DOMAIN_NAME) | sed -E -e 's/[^[:alnum:]]+/-/g' | cut -c1-100)

STATE_BUCKET   ?= terraform.agilestacks.com
STATE_REGION   ?= us-east-1

export AWS_DEFAULT_REGION ?= us-east-2

export TF_LOG      ?= info
export TF_DATA_DIR ?= .terraform/$(DOMAIN_NAME)
export TF_LOG_PATH ?= $(TF_DATA_DIR)/terraform.log

export TF_VAR_domain_name  := $(DOMAIN_NAME)
export TF_VAR_name         := $(NAME)
export TF_VAR_base_domain  := $(BASE_DOMAIN)
export TF_VAR_cluster_name ?= $(or $(CLUSTER_NAME),$(NAME2))
export TF_VAR_keypair      ?= agilestacks
export TF_VAR_n_zones      ?= 2
export TF_VAR_eks_admin    ?= $(USER)
export TF_VAR_worker_count         ?= 2
export TF_VAR_worker_instance_type ?= r5.large
export TF_VAR_worker_spot_price    ?= 0.06

kubectl     ?= kubectl --kubeconfig=kubeconfig.$(DOMAIN_NAME)
terraform   ?= terraform-v0.11
TF_CLI_ARGS ?= -no-color -input=false
TFPLAN      := $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

deploy: init import plan apply iam gpu storage output

init:
	@mkdir -p $(TF_DATA_DIR)
	$(terraform) init -get=true $(TF_CLI_ARGS) -reconfigure -force-copy  \
		-backend=true -input=false \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="region=$(STATE_REGION)" \
		-backend-config="key=$(DOMAIN_NAME)/stack-k8s-eks/$(COMPONENT_NAME)/terraform.tfstate" \
		-backend-config="profile=$(AWS_PROFILE)"
.PHONY: init

plan:
	$(terraform) plan $(TF_CLI_ARGS) -refresh=true -module-depth=-1 -out=$(TFPLAN)
.PHONY: plan

apply:
	$(terraform) apply $(TF_CLI_ARGS) -Xshadow=false $(TFPLAN)
	@echo
.PHONY: apply

iam:
	$(kubectl) apply -f $(TF_DATA_DIR)/aws-auth.yaml
.PHONY: iam

# https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v1.12/nvidia-device-plugin.yml
gpu:
	$(kubectl) apply -f nvidia-device-plugin.yaml
.PHONY: gpu

storage:
	$(kubectl) apply -f storage-class.yaml
.PHONY: storage

output:
	@echo
	@echo Outputs:
	@echo dns_name = $(NAME)
	@echo dns_base_domain = $(BASE_DOMAIN)
	@echo cluster_name = $(TF_VAR_cluster_name)
	@echo
.PHONY: output

undeploy: init import destroy apply

destroy: TF_CLI_ARGS:=-destroy $(TF_CLI_ARGS)
destroy: plan

import: init import_route53
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_instance_profile.node eks-node-$(NAME2)
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_role.node             eks-node-$(NAME2)
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_role.cluster          eks-cluster-$(NAME2)
.PHONY: import

import_route53: init
	@set -e; trap 'echo $$id' EXIT; \
		id=$$(AWS="$(aws)" JQ="$(jq)" bin/route53-zone-by-domain.sh $(DOMAIN_NAME)); \
		if test -n "$$id"; then $(terraform) import $(TF_CLI_ARGS) aws_route53_zone.main "$$id" || exit 0; fi
.PHONY: import_route53
