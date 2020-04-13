resource "aws_vpc" "cluster" {
  cidr_block = var.cidr_block

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
  custom_availability_zones = split(",", var.availability_zones)
  n_zones                   = length(local.custom_availability_zones) > 1 ? length(local.custom_availability_zones) : var.n_zones

  # TODO conditional operator cannot be used with list values prior 0.12
  # availability_zones = "${length(local.custom_availability_zones) > 0 ? local.custom_availability_zones : data.aws_availability_zones.available.names}"
  availability_zones_set = {
    custom = local.custom_availability_zones
    available = slice(
      distinct(compact(concat([var.availability_zone], data.aws_availability_zones.available.names))),
      0, local.n_zones)
  }
  availability_zones = local.availability_zones_set[length(local.custom_availability_zones) > 1 ? "custom" : "available"]
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
    "kind"                                      = "public"
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
