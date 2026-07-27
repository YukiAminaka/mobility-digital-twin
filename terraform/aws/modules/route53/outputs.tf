output "subdomain_zone_id" {
  value       = aws_route53_zone.velo_twin.zone_id
  description = "Hosted zone ID for the velotwin subdomain"
}
