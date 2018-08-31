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

variable "bucket" {
  description = "S3 bucket name"
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

variable "availability_zones" {
  default = []
  type = "list"
}

variable "worker_instance_type" {
  default = "r4.large"
  type = "string"
}

variable "worker_count" {
  default = "2"
  type = "string"
}

variable "worker_spot_price" {
  default = ""
  type = "string"
}

locals {
  name2 = "${replace("${var.domain_name}", ".", "-")}"
}
