provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Deploying Microservices on Amazon EKS"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}