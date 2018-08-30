.DEFAULT_GOAL := deploy

COMPONENT_NAME ?= stack-k8s-eks
DOMAIN_NAME    ?= eks-1.kubernetes.delivery
STATE_BUCKET   ?= terraform.agilestacks.com
STATE_REGION   ?= us-east-1

export AWS_PROFILE        ?= default
export AWS_DEFAULT_REGION ?= us-east-1
export TF_LOG             ?= warn
export TF_LOG_PATH        ?= .terraform/$(DOMAIN_NAME).log
export TF_OPTS            ?= -no-color
export TF_UPDATE          ?= -update

export TF_VAR_domain_name  := $(DOMAIN_NAME)
export TF_VAR_cluster_name ?= $(shell echo $(DOMAIN_NAME) | cut -d. -f1)

kubectl ?= kubectl
terraform ?= terraform-v0.11
TFPLAN ?= .terraform/$(DOMAIN_NAME).tfplan

deploy: init plan apply iam

init:
	@mkdir -p .terraform
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
	$(kubectl) --kubeconfig=kubeconfig.$(DOMAIN_NAME) apply -f .terraform/$(DOMAIN_NAME)-aws-auth.yaml
.PHONY: iam

undeploy: init destroy apply

destroy: TF_OPTS=-destroy
destroy: plan
