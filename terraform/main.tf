# ─────────────────────────────────────────────────────────────────
# Terraform — AWS Infrastructure for devops-app
# Creates: VPC → EKS Cluster → ECR Repository → S3 state bucket
# Usage:
#   cd terraform
#   terraform init
#   terraform plan
#   terraform apply
# ─────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — uncomment once you have an S3 bucket
  # backend "s3" {
  #   bucket         = "YOUR-terraform-state-bucket"
  #   key            = "devops-app/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "terraform-state-lock"   # prevents concurrent applies
  # }
}

provider "aws" {
  region = var.aws_region
}

# ─── Variables ─────────────────────────────────────────────────
variable "aws_region"    { default = "eu-west-1" }
variable "project_name"  { default = "devops-app" }
variable "environment"   { default = "nonprod" }
variable "cluster_version" { default = "1.29" }

# ─── VPC ───────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true   # cost saving for nonprod

  # Tags required by EKS
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  tags = local.common_tags
}

# ─── EKS Cluster ───────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # Enable IRSA — allows pods to assume IAM roles securely
  enable_irsa = true

  eks_managed_node_groups = {
    app_nodes = {
      instance_types = ["t3.small"]   # cheap for portfolio/demo
      min_size       = 1
      max_size       = 3
      desired_size   = 2

      labels = {
        Environment = var.environment
        Project     = var.project_name
      }
    }
  }

  tags = local.common_tags
}

# ─── ECR — Docker image registry ───────────────────────────────
resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true   # auto Trivy-style scan on every push
  }

  tags = local.common_tags
}

# Lifecycle policy — keep only last 10 images (cost saving)
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ─── S3 for Terraform state ────────────────────────────────────
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration { status = "Enabled" }
}

# ─── Outputs ───────────────────────────────────────────────────
output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "ecr_repo_url"     { value = aws_ecr_repository.app.repository_url }

# ─── Locals ────────────────────────────────────────────────────
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}
