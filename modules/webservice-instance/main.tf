resource "aws_route53_zone" "domain" {
    name = var.domain
}

resource "aws_lightsail_domain" "domain" {
  domain_name = aws_route53_zone.domain.name
}

resource "aws_lightsail_domain_entry" "frontend-lb-alias" {
  domain_name = aws_lightsail_domain.domain.domain_name
  name        = ""
  type        = "A"
  target      = aws_lightsail_lb.frontend.dns_name
  is_alias    = true
}

resource "aws_lightsail_lb" "frontend" {
  name              = "frontend"
  health_check_path = "/"
  instance_port     = "80"
}

resource "aws_lightsail_lb_certificate" "frontend" {
  name                      = "lb-certificate"
  lb_name                   = aws_lightsail_lb.frontend.id
  domain_name               = var.domain
  subject_alternative_names = ["www.${var.domain}"]
  depends_on                = [
    aws_lightsail_domain.domain,
    aws_route53_zone.domain,
  ]
}

resource "aws_route53_record" "frontend-lb-certificate-validation" {
  for_each        = {
    for dvo in aws_lightsail_lb_certificate.frontend.domain_validation_records : dvo.domain_name => {
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

resource "aws_lightsail_lb_https_redirection_policy" "frontend" {
  count   = var.enforce-https ? 1 : 0
  lb_name = aws_lightsail_lb.frontend.name
  enabled = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_lightsail_instance" "webservice" {
  name              = "webservice-instance"
  availability_zone = data.aws_availability_zones.available.names[0]
  bundle_id         = "nano_3_0"
  blueprint_id      = "amazon_linux_2023"
  user_data         = <<EOF
#!/bin/sh
dnf install -y docker
systemctl enable --now docker.service
docker container stop webservice || true
docker container rm -f webservice || true
docker run \
    --name webservice \
    --publish 80:5678 \
    --restart=always \
    -d "${var.container-image}" \
    -text "${var.display-text}"
EOF
}

resource "aws_lightsail_lb_attachment" "webservice" {
  lb_name       = aws_lightsail_lb.frontend.name
  instance_name = aws_lightsail_instance.webservice.name
}

resource "aws_lightsail_lb_certificate_attachment" "webservice" {
  lb_name          = aws_lightsail_lb.frontend.name
  certificate_name = aws_lightsail_lb_certificate.frontend.name
}

resource "aws_lightsail_instance_public_ports" "webservice-instance-ssh" {
  count         = var.ec2-enable-access-ssh ? 1 : 0
  instance_name = aws_lightsail_instance.webservice.name
  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }
}

variable "service-power" {
  type        = string
  description = "Lightsail instance type"
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

variable "ec2-enable-access-ssh" {
  type        = bool
  description = "Open ssh port to public"
}

variable "enforce-https" {
  type        = bool
  description = "Redirect from HTTP to HTTPS"
}
