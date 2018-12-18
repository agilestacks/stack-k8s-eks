.DEFAULT_GOAL := deploy

COMPONENT_NAME ?= stack-k8s-eks
DOMAIN_NAME    ?= eks-1.kubernetes.delivery
NAME           := $(shell echo $(DOMAIN_NAME) | cut -d. -f1)
BASE_DOMAIN    := $(shell echo $(DOMAIN_NAME) | cut -d. -f2-)
STATE_BUCKET   ?= terraform.agilestacks.com
STATE_REGION   ?= us-east-1

export AWS_DEFAULT_REGION ?= us-east-1
export TF_LOG             ?= warn
TF_DATA_DIR               := .terraform
export TF_LOG_PATH        ?= $(TF_DATA_DIR)/$(DOMAIN_NAME).log
export TF_OPTS            ?= -no-color
export TF_UPDATE          ?= -update

export TF_VAR_domain_name  := $(DOMAIN_NAME)
export TF_VAR_name         := $(NAME)
export TF_VAR_base_domain  := $(BASE_DOMAIN)
export TF_VAR_cluster_name ?= $(NAME)
export TF_VAR_bucket       ?= files.$(DOMAIN_NAME)

kubectl ?= kubectl --kubeconfig=kubeconfig.$(DOMAIN_NAME)
terraform ?= terraform-v0.11
TFPLAN ?= $(TF_DATA_DIR)/$(DOMAIN_NAME).tfplan

deploy: init plan apply iam automation-hub output

init:
	@mkdir -p $(TF_DATA_DIR)
	$(terraform) init -get=true $(TF_CMD_OPTS) -reconfigure -force-copy  \
		-backend=true -input=false \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="region=$(STATE_REGION)" \
		-backend-config="key=$(DOMAIN_NAME)/stack-k8s-eks/$(COMPONENT_NAME)/terraform.tfstate" \
		-backend-config="profile=$(AWS_PROFILE)"
.PHONY: init

get:
	$(terraform) get $(TF_UPDATE)
.PHONY: get

plan:
	$(terraform) plan $(TF_OPTS) -refresh=true -module-depth=-1 -out=$(TFPLAN)
.PHONY: plan

apply:
	$(terraform) apply $(TF_OPTS) -Xshadow=false $(TFPLAN)
	@echo
.PHONY: apply

iam:
	$(kubectl) apply -f $(TF_DATA_DIR)/$(DOMAIN_NAME)-aws-auth.yaml
.PHONY: iam

automation-hub:
	$(kubectl) apply -f automation-hub.yaml
.PHONY: automation-hub

output:
	@echo
	@echo Outputs:
	@echo dns_name = $(NAME)
	@echo dns_base_domain = $(BASE_DOMAIN)
	@echo
.PHONY: output

undeploy: init destroy apply

destroy: TF_OPTS=-destroy
destroy: plan
