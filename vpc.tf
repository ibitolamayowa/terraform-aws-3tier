# Create the VPC
resource "aws_vpc" "aws_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"
}

# Create the public subnets in each AZ
resource "aws_subnet" "public" {
  count = 2
  cidr_block = "10.0.${count.index}.0/24"
  vpc_id = aws_vpc.aws_vpc.id
  availability_zone = "us-west-2${element(["a", "b"], count.index)}"
  map_public_ip_on_launch = true
}

# Create the private subnets in each AZ
resource "aws_subnet" "private" {
  count = 4
  cidr_block = "10.0.${count.index + 10}.0/24"
  vpc_id = aws_vpc.aws_vpc.id
  availability_zone = "us-west-2${element(["a", "b"], count.index % 2)}"
}

# Create an internet gateway for the public subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.aws_vpc.id
}


# Create a NAT gateway in one of the AZs for the private subnets
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.private[0].id
}

# Create an Elastic IP for the NAT gateway
resource "aws_eip" "nat" {
  vpc = true
}

# Create a route table for the public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_route_tavble"
  }
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public" {
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create a route table for the private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private_route_table"
  }
}

# Associate the private subnets with the private route table
resource "aws_route_table_association" "private" {
  count = 4
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

output "availability_zones_private" {
  value = aws_subnet.private[*].availability_zone
}

output "private_cidr" {
  value = aws_subnet.private[*].cidr_block
}

output "public_cidr" {
  value = aws_subnet.public[*].cidr_block
}

output "availability_zones_public" {
  value = aws_subnet.public[*].availability_zone
}

output "vpc_id" {
  value = aws_vpc.aws_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}