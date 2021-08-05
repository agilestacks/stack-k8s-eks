terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.52.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "3.1.0"
    }
  }
  required_version = ">= 0.15"
  backend "s3" {}
}

provider "aws" {
  alias   = "dns"
  region  = "us-east-1" # only used to setup public Route53 zone

  access_key = var.external_aws_access_key_id
  secret_key = var.external_aws_secret_access_key
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

locals {
  partition = data.aws_partition.current.partition
}
