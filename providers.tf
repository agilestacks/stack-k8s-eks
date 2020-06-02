terraform {
  required_version = ">= 0.12"
  backend "s3" {}
}

provider "aws" {
  version = "2.61.0"
}

provider "aws" {
  alias   = "dns"
  region  = "us-east-1" # only used to setup public Route53 zone

  access_key = var.external_aws_access_key_id
  secret_key = var.external_aws_secret_access_key
}

provider "local" {
  version = "1.4.0"
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

locals {
  partition = data.aws_partition.current.partition
}