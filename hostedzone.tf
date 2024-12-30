
resource "aws_route53_zone" "hosted_zone" {
  name = "devopstrng.xyz"
}

resource "aws_route53_record" "primary_rds_cname" {
  zone_id = aws_route53_zone.hosted_zone.id
  name    = "db.devopstrng.xyz"
  type    = "CNAME"
  ttl     = 300
  records = [aws_db_instance.primary_rds.endpoint]
}

resource "aws_route53_health_check" "rds_health_check" {
  ip_address         = aws_db_instance.primary_rds.endpoint
  port               = 3306
  type               = "TCP"
  failure_threshold  = 3
  request_interval   = 30
}