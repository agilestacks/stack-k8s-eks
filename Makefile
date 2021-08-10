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
export TF_VAR_keypair      ?=
export TF_VAR_n_zones      ?= 2
export TF_VAR_eks_admin    := $(or $(EKS_ADMIN),$(shell aws sts get-caller-identity --output json | jq -r .Arn | grep :user/ | cut -d/ -f2))
export TF_VAR_k8s_version  ?= $(K8S_VERSION)
export TF_VAR_worker_count         ?= 2
export TF_VAR_worker_instance_type ?= r5.large
export TF_VAR_worker_spot_price    ?= 0.06
export TF_VAR_external_aws_access_key_id     := $(EXTERNAL_AWS_ACCESS_KEY)
export TF_VAR_external_aws_secret_access_key := $(EXTERNAL_AWS_SECRET_KEY)

kubectl     ?= kubectl --kubeconfig=kubeconfig.$(DOMAIN_NAME)
terraform   ?= terraform
TF_CLI_ARGS ?= -input=false
TFPLAN      := $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

ifneq (,$(TF_VAR_vpc_id))
ifeq (true,$(FARGATE_ENABLED))
$(error Cannot deploy into existing VPC with Fargate enabled: feature not implemented)
endif
ifeq (,$(TF_VAR_availability_zones))
$(error Please specify cloud.availabilityZones when cloud.vpc.id is specified)
endif
endif

# If instance_type contains comma, ie. r5.large:1,m5.large:2,c5.large (implicit :1 weight)
# then it is Mixed ASG - with empty spot price that defaults on AWS side to on-demand price, or a specified spot price
# Else if spot price is set then it is a plain ASG with spot instances
# Else it is on-demand instances via native EKS nodegroup
comma := ,
WORKER_IMPL := $(if $(or $(findstring $(comma),$(TF_VAR_worker_instance_type)),$(TF_VAR_worker_spot_price)),autoscaling,nodegroup)

deploy: init import plan apply awsnoderole iam gpu createsa storage token upgrade output

init:
	@mkdir -p $(TF_DATA_DIR)
	@cp -v fragments/eks-worker-$(WORKER_IMPL).tf eks-worker.tf
	@rm -f existing-vpc.tf vpc.tf; if test -n "$(TF_VAR_vpc_id)"; then cp -v fragments/existing-vpc.tf .; else cp -v fragments/vpc.tf .; fi
	@rm -f existing-zone.tf zone.tf; if test -n "$(TF_VAR_vpc_id)"; then cp -v fragments/existing-zone.tf .; else cp -v fragments/zone.tf .; fi
	@rm -f existing-sg.tf sg.tf; if test -n "$(TF_VAR_worker_sg_id)"; then cp -v fragments/existing-sg.tf .; else cp -v fragments/sg.tf .; fi
	@if test "$(FARGATE_ENABLED)" = true; then cp -v fragments/eks-fargate.tf .; else rm -f eks-fargate.tf; fi
	@if test -n "$(TF_VAR_eks_admin)"; then cp -v fragments/aws-auth.tf .; else rm -f aws-auth.tf $(TF_DATA_DIR)/aws-auth.yaml; fi
	$(terraform) init -get=true $(TF_CLI_ARGS) -reconfigure -force-copy  \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="region=$(STATE_REGION)" \
		-backend-config="key=$(DOMAIN_NAME)/stack-k8s-eks/$(COMPONENT_NAME)/terraform.tfstate" \
		-backend-config="profile=$(AWS_PROFILE)"
.PHONY: init

plan:
	$(terraform) plan $(TF_CLI_ARGS) -out=$(TFPLAN)
.PHONY: plan

apply:
	$(terraform) apply $(TF_CLI_ARGS) $(TFPLAN)
	@echo
.PHONY: apply

# 0.13upgrade: init
#	$(terraform) 0.13upgrade -yes

awsnoderole:
	set -xe; arn=$$($(terraform) output -json | jq -r .aws_node_role_arn.value); \
	if test "$$($(kubectl) -n kube-system get serviceaccount aws-node -o json | jq -r .metadata.annotations[\"eks.amazonaws.com/role-arn\"])" != "$$arn"; then \
		$(kubectl) -n kube-system annotate serviceaccount --overwrite=true aws-node \
			eks.amazonaws.com/role-arn=$$arn; \
		$(kubectl) -n kube-system delete pod -l k8s-app=aws-node; \
	fi
.PHONY: awsnoderole

iam:
    # Warning: kubectl apply should be used... below is ok
	if test -f $(TF_DATA_DIR)/aws-auth.yaml; then $(kubectl) apply -f $(TF_DATA_DIR)/aws-auth.yaml; fi
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

import: init
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_instance_profile.node eks-node-$(NAME2)
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_role.node             $$(echo eks-node-$(NAME2) | cut -c1-64)
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_role.aws_node         $$(echo eks-aws-node-$(NAME2) | cut -c1-64)
	-$(terraform) import $(TF_CLI_ARGS) aws_iam_role.cluster          $$(echo eks-cluster-$(NAME2) | cut -c1-64)
ifeq (,$(TF_VAR_vpc_id))
import: import_route53
endif
.PHONY: import

import_route53: PARENT_ZID=$(shell AWS="$(aws)" JQ="$(jq)" bin/route53-zone-by-domain.sh $(BASE_DOMAIN))
import_route53: init
	@set -e; trap 'echo $$id' EXIT; \
		id=$$(AWS="$(aws)" JQ="$(jq)" bin/route53-zone-by-domain.sh $(DOMAIN_NAME)); \
		if test -n "$$id"; then $(terraform) import $(TF_CLI_ARGS) aws_route53_zone.cluster "$$id" || exit 0; fi
	-$(terraform) import $(TF_CLI_ARGS) aws_route53_record.ns "$(PARENT_ZID)_$(DOMAIN_NAME)_NS"
.PHONY: import_route53

upgrade:
	bin/upgrade.sh
.PHONY: upgrade
