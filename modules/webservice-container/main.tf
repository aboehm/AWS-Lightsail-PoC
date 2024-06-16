resource "aws_route53_zone" "domain" {
  name = var.domain
}

resource "aws_lightsail_domain" "domain" {
  domain_name = aws_route53_zone.domain.name
}

resource "aws_route53_record" "webservice-domain-alias" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = var.domain
  type    = "A"
  alias  {
    # AWS provider doesn't give us the domain, but a URL to the domain
    name                   = replace(
      replace(aws_lightsail_container_service.webservice.url, "https://", ""),
      "/",
      ""
    )
    # Zone ID for region is pre-defined by AWS, here for us-east-1
    # https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-route-53-alias-record-for-container-service.html
    zone_id                = "Z06246771KYU0IRHI74W4"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "webservice-www-alias" {
  zone_id = aws_route53_zone.domain.zone_id
  name    = "www.${var.domain}"
  type    = "CNAME"
  records = [
    # AWS provider doesn't give us the domain, but a URL to the domain
    replace(
      replace(aws_lightsail_container_service.webservice.url, "https://", ""),
      "/",
      ""
    )
  ]
  ttl     = 60
}

resource "aws_lightsail_certificate" "webservice" {
  name                      = "container-certificate-1"
  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]

  # Ensure all DNS resources are created before trying to get a certificate
  depends_on  = [
    aws_lightsail_domain.domain,
    aws_route53_zone.domain,
  ]
}

resource "aws_route53_record" "frontend-certificate-validation" {
  for_each        = {
    for dvo in aws_lightsail_certificate.webservice.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.domain.zone_id
}

resource "aws_lightsail_container_service" "webservice" {
  name        = "webservice-container"
  power       = var.service-power
  scale       = var.service-instances
  is_disabled = false
  public_domain_names {
    certificate {
      certificate_name = aws_lightsail_certificate.webservice.name
      domain_names     = [
        var.domain,
        "www.${var.domain}",
      ]
    }
  }

  # DNS entries must be created for certificate validation
  depends_on = [aws_route53_record.frontend-certificate-validation]
}

resource "aws_lightsail_container_service_deployment_version" "webservice" {
  service_name = aws_lightsail_container_service.webservice.name

  container {
    container_name = "webservice"
    image          = var.container-image 
    command        = [
      "-text",
      var.display-text,
    ]
    ports = {
      5678 = "HTTP"
    }
  }

  public_endpoint {
    container_name = "webservice"
    container_port = 5678
    health_check {
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout_seconds     = 2
      interval_seconds    = 5
      path                = "/"
      success_codes       = "200"
    }
  }
}

variable "service-power" {
  type        = string
  description = "Lightsail instance type"
}

variable "service-instances" {
  type        = number
  description = "Number of instances of the services"
}

variable "display-text" {
  type        = string
  description = "Text returned by web service"
  sensitive   = true
}

variable "domain" {
  type        = string
  description = "Domain name"
}

variable "container-image" {
  type        = string
  description = "Image URI to deploy"
}
