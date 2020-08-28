.DEFAULT_GOAL := deploy

COMPONENT_NAME  ?= stack-k8s-eks
DOMAIN_NAME     ?= eks-1.dev.superhub.io
FARGATE_ENABLED ?= false
NAME            := $(shell echo $(DOMAIN_NAME) | cut -d. -f1)
BASE_DOMAIN     := $(shell echo $(DOMAIN_NAME) | cut -d. -f2-)
NAME2           := $(shell echo $(DOMAIN_NAME) | sed -E -e 's/[^[:alnum:]]+/-/g' | cut -c1-100)

export CLUSTER_NAME := $(or $(CLUSTER_NAME),$(NAME2))

STATE_BUCKET ?= terraform.agilestacks.com
STATE_REGION ?= us-east-1

SERVICE_ACCOUNT ?= asi

export AWS_DEFAULT_REGION ?= us-east-2

export TF_DATA_DIR ?= .terraform/$(DOMAIN_NAME)
export TF_LOG_PATH ?= $(TF_DATA_DIR)/terraform.log

export TF_VAR_domain_name  := $(DOMAIN_NAME)
export TF_VAR_name         := $(NAME)
export TF_VAR_base_domain  := $(BASE_DOMAIN)
export TF_VAR_cluster_name ?= $(CLUSTER_NAME)
export TF_VAR_keypair      ?= agilestacks
export TF_VAR_n_zones      ?= 2
# TODO make admin user trully optional
export TF_VAR_eks_admin    := $(or $(EKS_ADMIN),$(shell aws sts get-caller-identity --output json | jq -r .Arn | cut -d/ -f2))
export TF_VAR_k8s_version  ?= $(K8S_VERSION)
export TF_VAR_worker_count         ?= 2
export TF_VAR_worker_instance_type ?= r5.large
export TF_VAR_worker_spot_price    ?= 0.06
export TF_VAR_external_aws_access_key_id     := $(EXTERNAL_AWS_ACCESS_KEY)
export TF_VAR_external_aws_secret_access_key := $(EXTERNAL_AWS_SECRET_KEY)

kubectl     ?= kubectl --kubeconfig=kubeconfig.$(DOMAIN_NAME)
terraform   ?= terraform-v0.12
TF_CLI_ARGS ?= -input=false
TFPLAN      := $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

# If instance_type contains comma, ie. r5.large:1,m5.large:2,c5.large (implicit :1 weight)
# then it is Mixed ASG - with empty spot price that defaults on AWS side to on-demand price, or a specified spot price
# Else if spot price is set then it is a plain ASG with spot instances
# Else it is on-demand instances via native EKS nodegroup
comma := ,
WORKER_IMPL := $(if $(or $(findstring $(comma),$(TF_VAR_worker_instance_type)),$(TF_VAR_worker_spot_price)),autoscaling,nodegroup)

deploy: init import plan apply iam gpu createsa storage token upgrade output

init:
	@mkdir -p $(TF_DATA_DIR)
	@cp -v fragments/eks-worker-$(WORKER_IMPL).tf eks-worker.tf
	@if test $(FARGATE_ENABLED) = true; then cp -v fragments/eks-fargate.tf .; else rm -f eks-fargate.tf; fi
	$(terraform) init -get=true $(TF_CLI_ARGS) -reconfigure -force-copy  \
		-backend=true -input=false \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="region=$(STATE_REGION)" \
		-backend-config="key=$(DOMAIN_NAME)/stack-k8s-eks/$(COMPONENT_NAME)/terraform.tfstate" \
		-backend-config="profile=$(AWS_PROFILE)"
.PHONY: init

plan:
	$(terraform) plan $(TF_CLI_ARGS) -out=$(TFPLAN)
.PHONY: plan

apply:
	$(terraform) apply $(TF_CLI_ARGS) -Xshadow=false $(TFPLAN)
	@echo
.PHONY: apply

iam:
    # Warning: kubectl apply should be used... below is ok
	$(kubectl) apply -f $(TF_DATA_DIR)/aws-auth.yaml
.PHONY: iam

# https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml
gpu:
	$(kubectl) apply -f nvidia-device-plugin.yaml
.PHONY: gpu

createsa:
	$(kubectl) -n default get serviceaccount $(SERVICE_ACCOUNT) || \
		($(kubectl) -n default create serviceaccount $(SERVICE_ACCOUNT) && sleep 17)
	$(kubectl) get clusterrolebinding $(SERVICE_ACCOUNT)-cluster-admin-binding || \
		($(kubectl) create clusterrolebinding $(SERVICE_ACCOUNT)-cluster-admin-binding \
			--clusterrole=cluster-admin --serviceaccount=default:$(SERVICE_ACCOUNT) && sleep 7)
.PHONY: createsa

storage:
	$(kubectl) apply -f storage-class.yaml
.PHONY: storage

token:
	$(eval SECRET:=$(shell $(kubectl) -n default get serviceaccount $(SERVICE_ACCOUNT) -o json | \
		jq -r '.secrets[] | select(.name | contains("token")).name'))
	$(eval TOKEN:=$(shell $(kubectl) -n default get secret $(SECRET) -o json | \
		jq -r '.data.token'))
.PHONY: token

output:
	@echo
	@echo Outputs:
	@echo dns_name = $(NAME)
	@echo dns_base_domain = $(BASE_DOMAIN)
	@echo cluster_name = $(TF_VAR_cluster_name)
	@echo token = $(TOKEN) | $(HUB) util otp
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
		if test -n "$$id"; then $(terraform) import $(TF_CLI_ARGS) aws_route53_zone.cluster "$$id" || exit 0; fi
.PHONY: import_route53

upgrade:
	bin/upgrade.sh
.PHONY: upgrade
