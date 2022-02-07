resource "aws_service_discovery_service" "echo" {
    name = var.service_name
    description = "Lambda echo server demo"

    dns_config {
        namespace_id = aws_service_discovery_public_dns_namespace.echo.id

        dns_records {
            ttl = 10
            type = "A"
        }


        dns_records {
            ttl = 10
            type = "AAAA"
        }

        routing_policy = "MULTIVALUE"
    }

    tags = {
        Name = "Lambda echo server demo"
    }
}

resource "aws_service_discovery_public_dns_namespace" "echo" {
    name = "${var.domain_name}"
    description = "Lambda echo server demo"
    tags = {
        Name = "Lambda echo server demo"
    }
}