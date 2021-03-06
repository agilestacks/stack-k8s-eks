resource "aws_subnet" "fargate" {
  count = local.n_zones

  availability_zone = local.availability_zones[count.index]
  cidr_block        = "10.0.${count.index+128}.0/24" # TODO
  vpc_id            = aws_vpc.cluster.id

  tags = {
    "Name"                                      = "${local.name2}-fargate-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    "kind"                                      = "private"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.nodes[0].id

  depends_on = [aws_internet_gateway.cluster]
}

resource "aws_route_table" "fargate" {
  vpc_id = aws_vpc.cluster.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "fargate" {
  count = local.n_zones

  subnet_id      = aws_subnet.fargate[count.index].id
  route_table_id = aws_route_table.fargate.id
}
