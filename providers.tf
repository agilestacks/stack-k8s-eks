provider "aws" {
  version = "1.32.0"
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}
