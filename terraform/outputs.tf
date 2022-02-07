output "service_route53_zone_id" {
    value = aws_service_discovery_public_dns_namespace.echo.hosted_zone
}