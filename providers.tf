terraform {
  required_version = ">= 0.11.3"
  backend "s3" {}
}

provider "aws" {
  version = "1.60.0"
}

provider "local" {
  version = "1.1"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}
