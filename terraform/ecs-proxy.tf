resource "aws_ecs_cluster" "lambda_echo_proxy" {
    name = "LambdaEchoProxy"
    capacity_providers = ["FARGATE_SPOT"]
    tags = {
        Name = "Lambda echo server demo"
    }
}

resource "aws_ecs_task_definition" "lambda_echo_proxy" {
    family = "LambdaEchoProxy"
    cpu = 256
    execution_role_arn = aws_iam_role.lambda_echo_proxy_execution.arn
    memory = 512
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    runtime_platform {
        cpu_architecture = "ARM64"
        operating_system_family = "LINUX"
    }
    task_role_arn = aws_iam_role.lambda_echo_proxy_task.arn
    tags = {
        Name = "Lambda network proxy demo"
    }

    container_definitions = <<EOF
[
    {
        "name": "LambdaNetworkProxy",
        "command": ["-config", "ssm://${aws_ssm_parameter.proxy_config.name}"],
        "essential": true,
        "image": "dacut/proxy-ecs:latest",
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "${aws_cloudwatch_log_group.lambda_echo_proxy.name}",
                "awslogs-stream-prefix": "LambdaEchoProxy",
                "awslogs-region": "${var.region}"
            }
        },
        "portMappings": [
            {
                "containerPort": 7,
                "hostPort": 7,
                "protocol": "tcp"
            },
            {
                "containerPort": 7,
                "hostPort": 7,
                "protocol": "udp"
            }
        ]
    }
]
EOF
}

resource "aws_ecs_service" "lambda_echo_proxy" {
    name = "LambdaEchoProxy"
    cluster = aws_ecs_cluster.lambda_echo_proxy.id
    desired_count = 1
    enable_ecs_managed_tags = true
    launch_type = "FARGATE"
    network_configuration {
        subnets = aws_subnet.public[*].id
        security_groups = [aws_security_group.lambda_echo_proxy_ecs.id]
        assign_public_ip = true
    }
    platform_version = "1.4.0"
    propagate_tags = "TASK_DEFINITION"
    scheduling_strategy = "REPLICA"
    service_registries {
        registry_arn = aws_service_discovery_service.echo.arn
    }
    task_definition = aws_ecs_task_definition.lambda_echo_proxy.arn
    tags = {
        Name = "Lambda network proxy demo"
    }
}

resource "aws_cloudwatch_log_group" "lambda_echo_proxy" {
    name = "LambdaEchoProxy"
    retention_in_days = 7
    tags = {
        Name = "Lambda network proxy demo"
    }
}

resource "aws_security_group" "lambda_echo_proxy_ecs" {
    vpc_id = aws_vpc.vpc.id
    name = "Lambda Echo Proxy ECS permissions"
    description = "Allow public traffic to the ECS cluster on the echo port (7)"
}

resource "aws_security_group_rule" "lambda_echo_proxy_ingress_tcp_echo" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "ingress"
    from_port = 7
    to_port = 7
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "lambda_echo_proxy_ingress_udp_echo" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "ingress"
    from_port = 7
    to_port = 7
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "lambda_echo_proxy_egress_tcp_echo" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "egress"
    from_port = 7
    to_port = 7
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

resource "aws_security_group_rule" "lambda_echo_proxy_egress_udp_echo" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "egress"
    from_port = 7
    to_port = 7
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

# For talking to AWS services and Docker Hub.
resource "aws_security_group_rule" "lambda_echo_proxy_egress_https" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "egress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
}

# Our ports are ephemeral for talking to Lambda, so allow all traffic.
resource "aws_security_group_rule" "lambda_echo_proxy_ingress_lambda_function" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "ingress"
    from_port = -1
    to_port = -1
    protocol = "-1"
    source_security_group_id = aws_security_group.lambda_echo_lambda_function.id
}

resource "aws_security_group_rule" "lambda_echo_proxy_egress_lambda_function" {
    security_group_id = aws_security_group.lambda_echo_proxy_ecs.id
    type = "egress"
    from_port = -1
    to_port = -1
    protocol = "-1"
    source_security_group_id = aws_security_group.lambda_echo_lambda_function.id
}

resource "aws_ssm_parameter" "proxy_config" {
    name = "/LambdaEchoProxy/Config"
    description = "Lambda echo proxy config"
    type = "String"
    value = <<EOF
{
    "Listeners": [
        {
            "Protocol": "tcp",
            "Port": 7,
            "FunctionName": "${aws_lambda_function.echo.arn}"
        },
        {
            "Protocol": "udp",
            "Port": 7,
            "FunctionName": "${aws_lambda_function.echo.arn}"
        }
    ]
}
EOF

    tags = {
        Name = "Lambda network proxy demo"
    }
}

# Execution role
resource "aws_iam_role" "lambda_echo_proxy_execution" {
    name = "LambdaEchoProxyExecution"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            }
        }
    ]
}
EOF
}

resource "aws_iam_policy" "lambda_echo_proxy_execution" {
    name = "LambdaEchoProxyExecution"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachNetworkInterface",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNetworkInterfacePermission",
                "ec2:Describe*",
                "ec2:DetachNetworkInterface",
                "servicediscovery:GetOperation",
                "servicediscovery:ListTagsForResource"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "servicediscovery:DeregisterInstance",
                "servicediscovery:GetInstance",
                "servicediscovery:GetInstancesHealthStatus",
                "servicediscovery:GetNamespace",
                "servicediscovery:GetService",
                "servicediscovery:RegisterInstance"
            ],
            "Resource": [
                "${aws_cloudwatch_log_group.lambda_echo_proxy.arn}",
                "${aws_cloudwatch_log_group.lambda_echo_proxy.arn}:log-stream:*",
                "${aws_service_discovery_public_dns_namespace.echo.arn}",
                "${aws_service_discovery_service.echo.arn}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "servicediscovery:ListInstances",
                "servicediscovery:UpdateInstanceCustomHealthStatus"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "servicediscovery:ServiceArn": "${aws_service_discovery_service.echo.arn}"
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_echo_proxy_execution" {
    role = aws_iam_role.lambda_echo_proxy_execution.id
    policy_arn = aws_iam_policy.lambda_echo_proxy_execution.arn
}

resource "aws_iam_role" "lambda_echo_proxy_task" {
    name = "LambdaEchoProxyTask"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            }
        }
    ]
}
EOF
}

resource "aws_iam_policy" "lambda_echo_proxy_task" {
    name = "LambdaEchoProxyTask"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "ssm:GetParameter"
            ],
            "Resource": [
                "${aws_lambda_function.echo.arn}",
                "${aws_ssm_parameter.proxy_config.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_echo_proxy_task" {
    role = aws_iam_role.lambda_echo_proxy_task.id
    policy_arn = aws_iam_policy.lambda_echo_proxy_task.arn
}
