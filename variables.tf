variable "domain_name" {
  description = "Desired DNS domain of the cluster"
  default     = "eks-1.kubernetes.delivery"
  type        = "string"
}

variable "name" {
  description = "Desired DNS name of the cluster"
  type        = "string"
}

variable "base_domain" {
  description = "DNS base domain"
  type        = "string"
}

variable "cluster_name" {
  default = "eks-1"
  type = "string"
}

variable "eks_admin" {
  default = ""
  type = "string"
}

variable "keypair" {
  default = "agilestacks"
  type = "string"
}

variable "cidr_block" {
  default = "10.0.0.0/16"
  type = "string"
}

variable "n_zones" {
  default = "2"
  type = "string"
}

variable "availability_zone" {
  default = ""
  type = "string"
}


variable "availability_zones" {
  default = ""
  type = "string"
}

variable "worker_instance_type" {
  default = "r5.large"
  type = "string"
}

variable "worker_count" {
  default = "2"
  type = "string"
}

variable "worker_max_count" {
  default = "2"
  type = "string"
}

variable "worker_spot_price" {
  default = ""
  type = "string"
}

variable "worker_root_volume_type" {
  type        = "string"
  default     = "gp2"
  description = "The type of volume for the root block device of worker nodes."
}

variable "worker_root_volume_size" {
  type        = "string"
  default     = "30"
  description = "The size of the volume in gigabytes for the root block device of worker nodes."
}

variable "worker_root_volume_iops" {
  type    = "string"
  default = "100"

  description = <<EOF
The amount of provisioned IOPS for the root block device of worker nodes.
Ignored if the volume type is not io1.
EOF
}

locals {
  name2 = "${replace("${var.domain_name}", ".", "-")}"
}
