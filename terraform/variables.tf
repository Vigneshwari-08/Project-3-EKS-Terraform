# ============================================================
# variables.tf — All configurable values in one place
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "devops-project3"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_ami_type" {
  description = "EKS optimized AMI family for managed node groups"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  # Use a Free Tier eligible size by default so CI can create
  # the managed node group in accounts restricted to Free Tier.
  default = "t3.small"
}

variable "node_desired_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}
