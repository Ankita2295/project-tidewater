terraform {
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  backend "s3" {
    bucket         = "paylane-tfstate"
    key            = "settle/staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "paylane-tfstate-lock" # state locking
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Project     = "settle"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  name               = "settle-staging"
  cidr_block         = "10.10.0.0/16"
  region             = "us-east-1"
  single_nat_gateway = true # budget: 1 NAT gateway (~$32/mo) not 2
}

module "eks" {
  source               = "../../modules/eks"
  name                 = "settle-staging"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  node_instance_types  = ["t3.medium"]
  min_size             = 2
  max_size             = 3
  desired_size         = 2
}

module "rds" {
  source                     = "../../modules/rds"
  name                       = "settle-staging"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  instance_class             = "db.t4g.micro"
  multi_az                   = false # budget trade-off, see docs/DECISIONS.md
  allocated_storage          = 20
  allowed_security_group_ids = [aws_security_group.workload_egress.id]
}

module "redis" {
  source                     = "../../modules/redis"
  name                       = "settle-staging"
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  node_type                  = "cache.t4g.micro"
  allowed_security_group_ids = [aws_security_group.workload_egress.id]
}

resource "aws_security_group" "workload_egress" {
  name_prefix = "settle-staging-workload-"
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
  name              = "settle-staging"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = replace(module.eks.oidc_provider_url, "https://", "")
  namespace         = "settle"
  service_account   = "settle-api"
  secret_arns       = [module.rds.secret_arn, module.redis.secret_arn]
}
