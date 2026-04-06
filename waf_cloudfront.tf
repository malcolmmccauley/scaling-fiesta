# WAFv2 for CloudFront must be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Random secret shared between CloudFront and API Gateway
resource "random_password" "cloudfront_secret" {
  length  = 32
  special = false
}

# WAF Web ACL (CLOUDFRONT scope — must be in us-east-1)
resource "aws_wafv2_web_acl" "migration" {
  provider    = aws.us_east_1
  name        = "malco-migration"
  scope       = "CLOUDFRONT"
  description = "WAF for malco migration API"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "malco-migration-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    ManagedBy = "terraform"
  }
}

# ACM certificate in us-east-1 (required for CloudFront)
resource "aws_acm_certificate" "migration" {
  provider          = aws.us_east_1
  domain_name       = "migrate.significantmilestone.com"
  validation_method = "DNS"

  tags = {
    ManagedBy = "terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "migration_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.migration.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "migration" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.migration.arn
  validation_record_fqdns = [for r in aws_route53_record.migration_cert_validation : r.fqdn]
}

# CloudFront distribution in front of API Gateway
resource "aws_cloudfront_distribution" "migration" {
  enabled     = true
  comment     = "malco migration API"
  price_class = "PriceClass_100"
  web_acl_id  = aws_wafv2_web_acl.migration.arn
  aliases     = ["migrate.significantmilestone.com"]

  origin {
    domain_name = replace(replace(aws_apigatewayv2_api.migration.api_endpoint, "https://", ""), "/", "")
    origin_id   = "apigw"

    custom_header {
      name  = "x-origin-secret"
      value = random_password.cloudfront_secret.result
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "apigw"
    viewer_protocol_policy = "https-only"
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.migration.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    ManagedBy = "terraform"
  }
}

# Lock API Gateway to only accept requests from CloudFront
resource "aws_apigatewayv2_api_mapping" "migration" {
  depends_on = [aws_cloudfront_distribution.migration]
  api_id     = aws_apigatewayv2_api.migration.id
  stage      = aws_apigatewayv2_stage.migration.id
  domain_name = replace(replace(aws_apigatewayv2_api.migration.api_endpoint, "https://", ""), "/", "")
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.migration.domain_name
}
