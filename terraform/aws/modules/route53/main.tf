# Route53のホストゾーンを取得する
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# サブドメインのホストゾーンを作成する
resource "aws_route53_zone" "velo_twin" {
  name = var.subdomain_domain_name
}

resource "aws_route53_record" "ns_record_for_subdomain" {
  name    = aws_route53_zone.velo_twin.name
  zone_id = data.aws_route53_zone.main.zone_id
  records = [
    aws_route53_zone.velo_twin.name_servers[0],
    aws_route53_zone.velo_twin.name_servers[1],
    aws_route53_zone.velo_twin.name_servers[2],
    aws_route53_zone.velo_twin.name_servers[3]
  ]
  ttl  = 300
  type = "NS"
}
