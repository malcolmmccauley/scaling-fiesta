resource "aws_route53_zone" "main" {
  name = "significantmilestone.com"

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_route53_record" "migrate" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "migrate.significantmilestone.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.migration.domain_name
    zone_id                = aws_cloudfront_distribution.migration.hosted_zone_id
    evaluate_target_health = false
  }
}

output "route53_nameservers" {
  description = "Update your domain registrar to use these nameservers"
  value       = aws_route53_zone.main.name_servers
}

output "migrate_url" {
  description = "Migration API endpoint"
  value       = "https://migrate.significantmilestone.com/migrate"
}
