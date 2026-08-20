variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name" {
  description = "Name of the Amazon EKS cluster"
  type        = string
  default     = "wordpress-eks-cluster"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}