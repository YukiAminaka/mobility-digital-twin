# Route53のホストゾーンを取得する
data "aws_route53_zone" "main" {
  provider     = aws.route53_parent_zone
  name         = var.domain_name
  private_zone = false
}

# サブドメインの公開ホストゾーンを作成する(ACMのDNS検証に使用)
resource "aws_route53_zone" "velo_twin" {
  name = var.subdomain_domain_name
}

# サブドメインのプライベートホストゾーンを作成する
# internal ALBのエイリアスレコードなど、VPC内(SSMポートフォワード経由)からのみ
# 名前解決させたいレコードはこちらに作成する
resource "aws_route53_zone" "velo_twin_private" {
  name = var.subdomain_domain_name

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "ns_record_for_subdomain" {
  provider = aws.route53_parent_zone

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
