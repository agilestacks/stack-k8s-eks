variable "domain_name" {
  description = "Desired DNS domain of the cluster"
  default     = "eks-1.dev.superhub.io"
  type        = string
}

variable "name" {
  description = "Desired DNS name of the cluster"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.18"
}

variable "base_domain" {
  description = "DNS base domain"
  type        = string
}

variable "cluster_name" {
  default = "eks-1"
  type    = string
}

variable "eks_admin" {
  default = ""
  type    = string
}

variable "keypair" {
  default = "agilestacks"
  type    = string
}

variable "cidr_block" {
  default = "10.0.0.0/16"
  type    = string
}

variable "n_zones" {
  default = "2"
  type    = string
}

variable "availability_zone" {
  default = ""
  type    = string
}

variable "availability_zones" {
  default = ""
  type    = string
}

variable "worker_instance_type" {
  default = "r5.large"
  type    = string
}

variable "worker_count" {
  default = "2"
  type    = string
}

variable "worker_max_count" {
  default = "2"
  type    = string
}

variable "worker_spot_price" {
  default = ""
  type    = string
}

variable "worker_root_volume_type" {
  type        = string
  default     = "gp2"
  description = "The type of volume for the root block device of worker nodes."
}

variable "worker_root_volume_size" {
  type        = string
  default     = "50"
  description = "The size of the volume in gigabytes for the root block device of worker nodes."
}

variable "worker_root_volume_iops" {
  type    = string
  default = "100"

  description = <<EOF
The amount of provisioned IOPS for the root block device of worker nodes.
Ignored if the volume type is not io1.
EOF

}

# AWS defaults below
# https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html#mixed_instances_policy-instances_distribution
# https://docs.aws.amazon.com/autoscaling/ec2/APIReference/API_InstancesDistribution.html
variable "on_demand_base_capacity" {
  type    = string
  default = "0"
}

variable "on_demand_percentage_above_base_capacity" {
  type    = string
  default = "0" # the default is 100, yet we want spot instances thus 0
}

variable "spot_allocation_strategy" {
  type    = string
  default = "capacity-optimized"
}

variable "spot_instance_pools" {
  type    = string
  default = "2"
}

variable "external_aws_access_key_id" {
  type    = string
  default = ""
}

variable "external_aws_secret_access_key" {
  type    = string
  default = ""
}


locals {
  name2 = replace(var.domain_name, ".", "-")
}
