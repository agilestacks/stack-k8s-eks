resource "aws_vpc" "cluster" {
  cidr_block = "${var.cidr_block}"

  tags = "${
    map(
     "Name", "${local.name2}",
     "kubernetes.io/cluster/${var.cluster_name}", "shared",
    )
  }"
}

locals {
  custom_availability_zones = ["${split(",", var.availability_zones)}"]
  n_zones = "${length(local.custom_availability_zones) > 1 ? length(local.custom_availability_zones) : var.n_zones}"
  # conditional operator cannot be used with list values
  # availability_zones = "${length(local.custom_availability_zones) > 0 ? local.custom_availability_zones : data.aws_availability_zones.available.names}"
  availability_zones_set = {
    custom = "${local.custom_availability_zones}"
    available = "${slice(distinct(compact(concat(list(var.availability_zone), data.aws_availability_zones.available.names))), 0, local.n_zones)}"
  }
  availability_zones = "${local.availability_zones_set[length(local.custom_availability_zones) > 1 ? "custom" : "available"]}"
}

resource "aws_subnet" "nodes" {
  count = "${local.n_zones}"

  availability_zone = "${local.availability_zones[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24" # TODO
  vpc_id            = "${aws_vpc.cluster.id}"

  tags = "${
    map(
     "Name", "${local.name2}-${count.index}",
     "kubernetes.io/cluster/${var.cluster_name}", "shared",
    )
  }"
}

resource "aws_internet_gateway" "cluster" {
  vpc_id = "${aws_vpc.cluster.id}"

  tags {
    Name = "${local.name2}"
  }
}

resource "aws_route_table" "cluster" {
  vpc_id = "${aws_vpc.cluster.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.cluster.id}"
  }
}

resource "aws_route_table_association" "nodes" {
  count = "${local.n_zones}"

  subnet_id      = "${aws_subnet.nodes.*.id[count.index]}"
  route_table_id = "${aws_route_table.cluster.id}"
}
