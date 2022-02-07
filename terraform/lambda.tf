resource "aws_lambda_function" "echo" {
    depends_on = [
        aws_iam_policy.lambda_echo_lambda_function,
        aws_iam_role_policy_attachment.lambda_echo_lambda_function
    ]
    description = "Lambda implementation of the RFC 862 echo protocol"
    filename = "${path.module}/../lambda-echo-server-x86_64.zip"
    function_name = "EchoDemo"
    handler = "lambda-echo-server-linux-x86_64"
    memory_size = 128
    role = aws_iam_role.lambda_echo_lambda_function.arn
    runtime = "go1.x"
    source_code_hash = filebase64sha256("${path.module}/../lambda-echo-server-x86_64.zip")
    timeout = 30
    tags = {
        Name = "Lambda echo server demo"
    }

    vpc_config {
        security_group_ids = [aws_security_group.lambda_echo_lambda_function.id]
        subnet_ids = aws_subnet.private[*].id
    }
}

resource "aws_iam_role" "lambda_echo_lambda_function" {
    name = "LambdaEchoDemo-Lambda"
    depends_on = [aws_cloudwatch_log_group.lambda_echo_lambda_function]
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            }
        }
    ]
}
EOF

    tags = {
        Name = "Lambda echo server demo"
    }
}

resource "aws_iam_policy" "lambda_echo_lambda_function" {
    name = "LambdaEchoDemo-Lambda"
    description = "Allow Lambda echo implementation to save logs"

    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "${aws_cloudwatch_log_group.lambda_echo_lambda_function.arn}",
                "${aws_cloudwatch_log_group.lambda_echo_lambda_function.arn}:log-stream:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DeleteNetworkInterface",
                "ec2:AssignPrivateIpAddresses",
                "ec2:UnassignPrivateIpAddresses"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_cloudwatch_log_group" "lambda_echo_lambda_function" {
    name = "/aws/lambda/EchoDemo"
    retention_in_days = 7
    tags = {
        Name = "Lambda echo server demo"
    }
}

resource "aws_iam_role_policy_attachment" "lambda_echo_lambda_function" {
    role = aws_iam_role.lambda_echo_lambda_function.id
    policy_arn = aws_iam_policy.lambda_echo_lambda_function.arn
}

resource "aws_security_group" "lambda_echo_lambda_function" {
    vpc_id = aws_vpc.vpc.id
    name = "Lambda echo demo security group for the Lambda function"
    description = "Allow traffic to/from ECS"   
}

// Our ports are ephemeral; allow all TCP/UDP traffic to/from the proxy.

resource "aws_security_group_rule" "lambda_echo_lambda_function_ingress" {
    security_group_id = aws_security_group.lambda_echo_lambda_function.id
    type = "ingress"
    from_port = -1
    to_port = -1
    protocol = "-1"
    source_security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
}

resource "aws_security_group_rule" "lambda_echo_lambda_function_egress" {
    security_group_id = aws_security_group.lambda_echo_lambda_function.id
    type = "egress"
    from_port = -1
    to_port = -1
    protocol = "-1"
    source_security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
}

# Allow writing to CloudWatch logs
resource "aws_security_group_rule" "lambda_echo_lambda_function_egress_aws" {
    security_group_id = aws_security_group.lambda_echo_lambda_function.id
    type = "egress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
}
