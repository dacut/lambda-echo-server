resource "aws_vpc" "vpc" {
    cidr_block = var.ipv4_cidr_block
    enable_dns_support = true
    enable_dns_hostnames = false
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = "Lambda echo server demo"
    }
}

resource "aws_subnet" "public" {
    count = length(local.azs)
    vpc_id = aws_vpc.vpc.id
    assign_ipv6_address_on_creation = true
    availability_zone = local.azs[count.index]
    cidr_block = cidrsubnet(var.ipv4_cidr_block, 4, count.index)
    ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "Lambda echo server demo public subnet (${local.azs[count.index]})"
    }
}

resource "aws_subnet" "private" {
    count = length(local.azs)
    vpc_id = aws_vpc.vpc.id
    assign_ipv6_address_on_creation = true
    availability_zone = local.azs[count.index]
    cidr_block = cidrsubnet(var.ipv4_cidr_block, 4, 8+count.index)
    ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, 128+count.index)
    map_public_ip_on_launch = false
    tags = {
        Name = "Lambda echo server demo private subnet (${local.azs[count.index]})"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "Lambda echo server demo internet gateway"
    }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "Lambda echo server demo public route table"
    }
}

resource "aws_route" "public_ipv4" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route" "public_ipv6" {
    route_table_id = aws_route_table.public.id
    destination_ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "Lambda echo server demo private route table"
    }
}

resource "aws_route_table_association" "public" {
    count = length(local.azs)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
    count = length(local.azs)
    subnet_id = aws_subnet.private[count.index].id
    route_table_id = aws_route_table.private.id
}

# AWS service endpoints

# CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
    vpc_id = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.logs"
    subnet_ids = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.aws_endpoint.id]
    vpc_endpoint_type = "Interface"
}

# CloudWatch Monitoring
resource "aws_vpc_endpoint" "monitoring" {
    vpc_id = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.monitoring"
    subnet_ids = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.aws_endpoint.id]
    vpc_endpoint_type = "Interface"
}

# EC2
resource "aws_vpc_endpoint" "ec2" {
    vpc_id = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.ec2"
    subnet_ids = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.aws_endpoint.id]
    vpc_endpoint_type = "Interface"
}

# ECS telemetry
resource "aws_vpc_endpoint" "ecs_telemetry" {
    vpc_id = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.ecs-telemetry"
    subnet_ids = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.aws_endpoint.id]
    vpc_endpoint_type = "Interface"
}

# Lambda
resource "aws_vpc_endpoint" "lambda" {
    vpc_id = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.lambda"
    subnet_ids = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.aws_endpoint.id]
    vpc_endpoint_type = "Interface"
}

# S3 (yum updates for development)
resource "aws_vpc_endpoint" "s3" {
    vpc_id = aws_vpc.vpc.id
    service_name = "com.amazonaws.${var.region}.s3"
    subnet_ids = [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.aws_endpoint.id]
    vpc_endpoint_type = "Interface"
}

resource "aws_security_group" "aws_endpoint" {
    name = "Lambda echo server demo AWS endpoint security group"
    description = "Allow incoming traffic from the VPC to AWS services"
    vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "aws_endpoint_ingress_https" {
    security_group_id = aws_security_group.aws_endpoint.id
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
}
