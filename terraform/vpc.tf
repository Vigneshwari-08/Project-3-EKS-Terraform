# ============================================================
# vpc.tf — Networking foundation for EKS
# ============================================================
# EKS needs its own VPC with specific networking setup.
# This file creates everything networking-related:
#   - VPC (the private network boundary)
#   - 2 public subnets across 2 availability zones (for HA)
#   - Internet Gateway (allows traffic in/out)
#   - Route table (tells traffic how to get out)
#
# Why 2 subnets in 2 AZs?
#   EKS requires at least 2 AZs. If one AZ goes down,
#   your worker nodes in the other AZ keep running.
# ============================================================

# ── VPC ─────────────────────────────────────────────────────
# The VPC is your private network on AWS.
# Everything (EKS cluster, nodes) lives inside this boundary.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # 65,536 IP addresses available
  enable_dns_support   = true          # Required for EKS
  enable_dns_hostnames = true          # Required for EKS

  tags = {
    Name                                        = "devops-project3-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ── Public Subnet — AZ 1 (us-east-1a) ───────────────────────
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24" # 256 IPs for AZ 1
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Nodes get a public IP automatically

  tags = {
    Name                                        = "devops-project3-public-1a"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1" # Tells EKS this subnet can have load balancers
  }
}

# ── Public Subnet — AZ 2 (us-east-1b) ───────────────────────
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24" # 256 IPs for AZ 2
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "devops-project3-public-1b"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# ── Internet Gateway ─────────────────────────────────────────
# Without this, nothing inside the VPC can reach the internet.
# Nodes need it to pull Docker images, EKS needs it to communicate.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devops-project3-igw"
  }
}

# ── Route Table ──────────────────────────────────────────────
# Tells the subnets: "send all outbound traffic to the internet gateway"
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # All outbound traffic
    gateway_id = aws_internet_gateway.main.id # Goes through the IGW
  }

  tags = {
    Name = "devops-project3-rt"
  }
}

# ── Associate Route Table with both Subnets ──────────────────
# Without this association, subnets don't know about the route table.
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}
