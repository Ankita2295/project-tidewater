variable "name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "instance_class" {
  type    = string
  default = "db.t4g.micro" # staging budget default; prod overrides
}
variable "multi_az" {
  type    = bool
  default = false # staging: single-AZ to hit $250/mo. prod overrides to true.
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "allowed_security_group_ids" { type = list(string) }

resource "random_password" "master" {
  length  = 32
  special = false # avoid chars that need extra escaping in connection strings
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids # only the workload SG, never 0.0.0.0/0
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_kms_key" "db" {
  description         = "${var.name} RDS encryption"
  enable_key_rotation = true
}

resource "aws_db_instance" "this" {
  identifier     = var.name
  engine         = "postgres"
  engine_version = "15"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 3 # storage autoscaling headroom
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.db.arn

  db_name  = "settle"
  username = "settle_app"
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az                = var.multi_az
  publicly_accessible      = false
  backup_retention_period  = 7
  deletion_protection      = true
  skip_final_snapshot      = false
  final_snapshot_identifier = "${var.name}-final"

  # matches app-level requirement: statement timeout so a slow query
  # can't hold a connection open indefinitely under load
  parameter_group_name = aws_db_parameter_group.this.name
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg15"
  family = "postgres15"
  parameter {
    name  = "statement_timeout"
    value = "8000" # ms
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries slower than 1s
  }
}

resource "aws_secretsmanager_secret" "db_url" {
  name = "${var.name}/database-url"
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql://${aws_db_instance.this.username}:${random_password.master.result}@${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}"
}

output "endpoint" { value = aws_db_instance.this.endpoint }
output "secret_arn" { value = aws_secretsmanager_secret.db_url.arn }
output "security_group_id" { value = aws_security_group.db.id }
