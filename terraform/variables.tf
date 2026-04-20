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

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  # t3.medium = 2 vCPU, 4GB RAM
  # Minimum recommended for EKS — t2.micro is too small
  default     = "t3.medium"
}

variable "node_desired_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}
