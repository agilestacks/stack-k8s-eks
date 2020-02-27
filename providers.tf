terraform {
  required_version = ">= 0.11.10"
  backend "s3" {}
}

provider "aws" {
  version = "2.49.0"
}

provider "local" {
  version = "1.2.2"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}
