output "subdomain_zone_id" {
  value       = aws_route53_zone.velo_twin.zone_id
  description = "Public hosted zone ID for the velotwin subdomain (used for ACM DNS validation)"
}

output "private_subdomain_zone_id" {
  value       = aws_route53_zone.velo_twin_private.zone_id
  description = "Private hosted zone ID for the velotwin subdomain (VPC-internal name resolution)"
}
