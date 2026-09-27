terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "paylane-tfstate"
    key            = "settle/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "paylane-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "settle"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# Same modules as staging, different inputs — no copy-pasted module code.
module "vpc" {
  source             = "../../modules/vpc"
  name               = "settle-prod"
  cidr_block         = "10.20.0.0/16"
  region             = "us-east-1"
  single_nat_gateway = false # prod: NAT per AZ, no single point of failure
}

module "eks" {
  source              = "../../modules/eks"
  name                = "settle-prod"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  node_instance_types = ["m6i.large"]
  min_size            = 3
  max_size            = 6
  desired_size        = 3
}

module "rds" {
  source                     = "../../modules/rds"
  name                       = "settle-prod"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  instance_class             = "db.r6g.large"
  multi_az                   = true # prod: automatic failover
  allocated_storage          = 100
  allowed_security_group_ids = [aws_security_group.workload_egress.id]
}

module "redis" {
  source                     = "../../modules/redis"
  name                       = "settle-prod"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  node_type                  = "cache.r6g.large"
  allowed_security_group_ids = [aws_security_group.workload_egress.id]
}

resource "aws_security_group" "workload_egress" {
  name_prefix = "settle-prod-workload-"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "iam_settle_api" {
  source            = "../../modules/iam"
  name              = "settle-prod"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = replace(module.eks.oidc_provider_url, "https://", "")
  namespace         = "settle"
  service_account   = "settle-api"
  secret_arns       = [module.rds.secret_arn, module.redis.secret_arn]
}
