variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "node_type" {
  type    = string
  default = "cache.t4g.micro" # staging budget default
}
variable "allowed_security_group_ids" { type = list(string) }

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis" {
  name_prefix = "${var.name}-redis-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "random_password" "auth" {
  length  = 32
  special = false
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description           = "settle redis - job queue"
  engine                 = "redis"
  engine_version         = "7.1"
  node_type              = var.node_type
  num_cache_clusters     = 1 # staging: single node to hit budget; prod uses 2+ with auto-failover

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result
}

resource "aws_secretsmanager_secret" "redis_url" {
  name = "${var.name}/redis-url"
}

resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id     = aws_secretsmanager_secret.redis_url.id
  secret_string = "rediss://:${random_password.auth.result}@${aws_elasticache_replication_group.this.primary_endpoint_address}:6379"
}

output "primary_endpoint" { value = aws_elasticache_replication_group.this.primary_endpoint_address }
output "secret_arn" { value = aws_secretsmanager_secret.redis_url.arn }
output "security_group_id" { value = aws_security_group.redis.id }
