# ============================================================
# outputs.tf — Printed after terraform apply
# ============================================================
# The cluster_name and region outputs are used by the
# app pipeline (app.yml) to connect kubectl to this cluster.
# ============================================================

output "cluster_name" {
  description = "EKS cluster name — used by the app pipeline"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_region" {
  description = "AWS region the cluster is in"
  value       = var.aws_region
}

output "kubeconfig_command" {
  description = "Run this locally to configure kubectl to talk to your cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}
