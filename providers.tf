terraform {
  required_version = ">= 0.11.3"
  backend "s3" {}
}

provider "aws" {
  version = "1.35.0"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}
