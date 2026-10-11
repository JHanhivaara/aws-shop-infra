# Private network for the shop. No internet gateway: nothing in here is reachable from outside.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true # RDS endpoints are DNS names; Lambda needs to resolve them
  enable_dns_support   = true

  tags = { Name = "shop" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"

  tags = { Name = "shop-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-north-1b"

  tags = { Name = "shop-private-b" }
}
