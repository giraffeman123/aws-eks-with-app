# Retrieve information about your hosted zone from AWS
data "aws_route53_zone" "this" {
  name = var.main_domain_name
}


#-------------------- Create the TLS/SSL certificate for website domain --------------------
resource "aws_acm_certificate" "website_domain_cert" {
  domain_name               = var.website_domain
  validation_method         = "DNS"
  subject_alternative_names = []

  # Ensure that the resource is rebuilt before destruction when running an update
  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS record that will be used for our certificate validation
resource "aws_route53_record" "website_domain_cert_validation" {
  for_each = { for dvo in aws_acm_certificate.website_domain_cert.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    type   = dvo.resource_record_type
    record = dvo.resource_record_value
  } }

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
  zone_id = data.aws_route53_zone.this.zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "website_domain_validate_cert" {
  certificate_arn         = aws_acm_certificate.website_domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.website_domain_cert_validation : record.fqdn]

  depends_on = [aws_route53_record.website_domain_cert_validation]
}


#-------------------- Create the TLS/SSL certificate for argocd domain --------------------
resource "aws_acm_certificate" "argocd_domain_cert" {
  domain_name               = var.argocd_domain
  validation_method         = "DNS"
  subject_alternative_names = []

  # Ensure that the resource is rebuilt before destruction when running an update
  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS record that will be used for our certificate validation
resource "aws_route53_record" "argocd_domain_cert_validation" {
  for_each = { for dvo in aws_acm_certificate.argocd_domain_cert.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    type   = dvo.resource_record_type
    record = dvo.resource_record_value
  } }

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
  zone_id = data.aws_route53_zone.this.zone_id
}

# Validate the certificate
resource "aws_acm_certificate_validation" "argocd_domain_validate_cert" {
  certificate_arn         = aws_acm_certificate.argocd_domain_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.argocd_domain_cert_validation : record.fqdn]

  depends_on = [aws_route53_record.argocd_domain_cert_validation]
}