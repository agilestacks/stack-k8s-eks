terraform {
  required_version = ">= 0.12"
  backend "s3" {}
}

provider "aws" {
  version = "2.49.0"
}

provider "local" {
  version = "1.4.0"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}
