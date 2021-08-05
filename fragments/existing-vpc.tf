data "aws_vpc" "cluster" {
  id = var.vpc_id
}

data "aws_subnet_ids" "workers" {
  vpc_id = var.vpc_id
  filter {
    name   = "availability-zone"
    values = local.availability_zones
  }
}

# data "aws_subnet" "workers" {
#   for_each = data.aws_subnet_ids.workers.ids
#   id       = each.value
# }

data "aws_availability_zones" "zones" {
}

locals {
  custom_subnets = split(",", var.worker_subnet_ids)
  custom_zones   = split(",", var.availability_zones)

  vpc_id         = data.aws_vpc.cluster.id
  vpc_cidr_block = data.aws_vpc.cluster.cidr_block
  subnet_ids     = length(local.custom_subnets) > 1 ? local.custom_subnets : data.aws_subnet_ids.workers.ids

#   Unsupported attribute: object does not have an attribute named "availability_zone"
#   availability_zones = distinct(compact(data.aws_subnet.workers.*.availability_zone))
  availability_zones = length(local.custom_zones) > 1 ? local.custom_zones : data.aws_availability_zones.zones.names
}

variable "vpc_id" {
  default = ""
  type    = string
}

variable "worker_subnet_ids" {
  default = ""
  type    = string
}

variable "worker_sg_id" {
  default = ""
  type    = string
}
