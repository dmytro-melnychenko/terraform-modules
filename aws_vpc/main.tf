locals {

  max_subnet_length = max(
    length(var.private_subnets),
    length(var.db_subnets)
  )

  nat_gateway_count = var.private_subnets_single_nat ? 1 : var.one_nat_gateway_per_az ? length(var.availability_zones) : local.max_subnet_length

}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-vpc-${var.environment}",
      Environment = var.environment
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-igw-${var.environment}",
      Environment = var.environment
    }
  )
}

resource "aws_nat_gateway" "main" {
  count         = var.private_subnets_with_internet ? local.nat_gateway_count : 0
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  depends_on    = [aws_internet_gateway.main]

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-nat-${var.environment}-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_eip" "nat" {
  count = var.private_subnets_with_internet ? local.nat_gateway_count : 0
  vpc   = true

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-eip-${var.environment}-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.db_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)
  count             = length(var.db_subnets)


  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-db-subnet-${var.environment}-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)
  count             = length(var.private_subnets)

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-private-subnet-${var.environment}-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.public_subnets)
  map_public_ip_on_launch = true


  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-public-subnet-${var.environment}-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags, {
      Name = "${local.name}-routing-table-public"
    }
  )

}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnets)
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-routing-table-private-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_route" "private" {
  count                  = var.private_subnets_with_internet ? length(compact(var.private_subnets)) : 0
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.main.*.id, count.index)
}

resource "aws_route_table" "db" {
  count  = var.db_subnets_with_internet ? length(var.db_subnets) : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags, {
      Name        = "${local.name}-routing-table-db-${format("%03d", count.index + 1)}",
      Environment = var.environment
    }
  )
}

resource "aws_route" "db" {
  count                  = var.db_subnets_with_internet ? length(compact(var.db_subnets)) : 0
  route_table_id         = element(aws_route_table.db.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
  # nat_gateway_id         = element(aws_nat_gateway.main.*.id, count.index)
}

resource "aws_route_table_association" "db" {
  count          = var.db_subnets_with_internet ? length(var.db_subnets) : 0
  subnet_id      = element(aws_subnet.db.*.id, count.index)
  route_table_id = element(aws_route_table.db.*.id, count.index)
}


resource "aws_route_table_association" "private" {
  count          = var.private_subnets_with_internet ? length(var.private_subnets) : 0
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# resource "aws_flow_log" "main" {
#   iam_role_arn    = aws_iam_role.vpc-flow-logs-role.arn
#   log_destination = aws_cloudwatch_log_group.main.arn
#   traffic_type    = "ALL"
#   vpc_id          = aws_vpc.main.id
# }

# resource "aws_cloudwatch_log_group" "main" {
#   name = "${local.name}-cloudwatch-log-group"
# }

# resource "aws_iam_role" "vpc-flow-logs-role" {
#   name = "${local.name}-vpc-flow-logs-role"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "",
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "vpc-flow-logs.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy" "vpc-flow-logs-policy" {
#   name = "${local.name}-vpc-flow-logs-policy"
#   role = aws_iam_role.vpc-flow-logs-role.id

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents",
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams"
#       ],
#       "Effect": "Allow",
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }

