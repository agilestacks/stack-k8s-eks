resource "aws_vpc" "cluster" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = {
    "Name"                                      = local.name2
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<EOF
aws ec2 describe-security-groups \
        --no-paginate \
        --filters Name=vpc-id,Values=${self.id} \
        --query SecurityGroups \
        --output json \
    | jq -r '.[] | select(.GroupName != "default") | .GroupId' \
    | xargs -tn1 aws ec2 delete-security-group --group-id
EOF

  }
}

locals {
  custom_availability_zones    = split(",", var.availability_zones)
  n_custom_availability_zones  = length(local.custom_availability_zones)
  n_zones                      = local.n_custom_availability_zones > 1 ? local.n_custom_availability_zones : var.n_zones
  available_availability_zones = slice(
    distinct(compact(concat([var.availability_zone], data.aws_availability_zones.available.names))),
    0, local.n_zones)
  availability_zones = local.n_custom_availability_zones > 1 ? local.custom_availability_zones : local.available_availability_zones
}

resource "aws_subnet" "nodes" {
  count = local.n_zones

  availability_zone = local.availability_zones[count.index]
  cidr_block        = "10.0.${count.index}.0/24" # TODO
  vpc_id            = aws_vpc.cluster.id

  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "${local.name2}-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    "kind"                                      = "public"
  }

  # Destroy stray ENIs left by amazon-vpc-cni-k8s.
  # EKS masters also installs their own ENIs.
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<EOF
aws ec2 describe-network-interfaces \
        --no-paginate \
        --filters Name=subnet-id,Values=${self.id} Name=status,Values=available \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' \
        --output text \
    | xargs -tn1 aws ec2 delete-network-interface --network-interface-id
EOF

  }
}

resource "aws_internet_gateway" "cluster" {
  vpc_id = aws_vpc.cluster.id

  tags = {
    Name = local.name2
  }

  # Delete stray ELBs
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<EOF
aws elb describe-load-balancers \
        --no-paginate \
        --query LoadBalancerDescriptions \
        --output json \
    | jq -r '.[] | select(.VPCId == "${self.vpc_id}") | .LoadBalancerName' \
    | xargs -tn1 aws elb delete-load-balancer --load-balancer-name
EOF

  }
}

resource "aws_route_table" "cluster" {
  vpc_id = aws_vpc.cluster.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster.id
  }
}

resource "aws_route_table_association" "nodes" {
  count = local.n_zones

  subnet_id      = aws_subnet.nodes[count.index].id
  route_table_id = aws_route_table.cluster.id
}
