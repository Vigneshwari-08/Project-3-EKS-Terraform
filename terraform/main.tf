# ============================================================
# main.tf — EKS Cluster + Node Group
# ============================================================
# This file creates:
#   1. IAM roles  (permissions EKS needs to work)
#   2. EKS cluster (the managed control plane)
#   3. Node group  (the 2 worker nodes that run your pods)
#
# ⚠️  IMPORTANT: This is run ONCE to set up infrastructure.
#     It is NOT part of the app deployment pipeline.
#     Run manually: terraform apply
#     Tear down:    terraform destroy
# ============================================================

provider "aws" {
  region = var.aws_region
}

# ── IAM Role for EKS Control Plane ──────────────────────────
# EKS needs permission to manage AWS resources on your behalf.
# This role grants those permissions.
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  # This "assume_role_policy" says: "the EKS service is allowed to use this role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach the AWS-managed EKS policy to the role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# ── IAM Role for Worker Nodes ────────────────────────────────
# The worker nodes also need permissions:
#   - Pull Docker images from ECR
#   - Register themselves with the EKS cluster
#   - Read networking config (CNI)
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Three policies the worker nodes need
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# ── EKS Cluster ──────────────────────────────────────────────
# This is the managed Kubernetes control plane.
# AWS runs and maintains the API server, etcd, and scheduler.
# You don't see or manage the control plane nodes — AWS does.
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    # Place the cluster in both subnets (across both AZs)
    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ]
    endpoint_public_access = true # Allows kubectl from your machine / GitHub Actions
  }

  # Cluster can only be created after IAM role policies are attached
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name    = var.cluster_name
    Project = "DevOps-Project3"
  }
}

# ── EKS Node Group ───────────────────────────────────────────
# A node group is a set of EC2 instances that act as worker nodes.
# EKS manages the lifecycle of these nodes for you —
# you just say how many you want and what size.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn

  # Make the node image explicit so EKS does not pick an
  # unsupported default AMI family for this Kubernetes version.
  ami_type = var.node_ami_type

  # Spread nodes across both subnets (both AZs)
  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  # Node size — t3.medium is the minimum recommended for EKS
  instance_types = [var.node_instance_type]

  # Scaling config:
  #   desired_size = how many nodes to start with
  #   min_size     = never go below this
  #   max_size     = never go above this
  scaling_config {
    desired_size = var.node_desired_count
    min_size     = 1
    max_size     = 4
  }

  # Nodes can only be created after their IAM role policies are attached
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]

  tags = {
    Name    = "${var.cluster_name}-node"
    Project = "DevOps-Project3"
  }
}
