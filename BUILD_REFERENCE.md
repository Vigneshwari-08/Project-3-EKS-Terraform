# EKS Provisioning Reference

This file is a technical reference for how EKS is provisioned and configured in this project.

It is intentionally narrower than [README.md](/Users/vigneshwarik/Desktop/Project3/README.md): the README covers setup and usage, while this file explains the Terraform design and the AWS resources behind the cluster.

## Provisioning Flow

The EKS environment is created by Terraform through the infrastructure workflow.

The provisioning order is:

1. create the VPC and subnet networking
2. create IAM roles for the EKS control plane and worker nodes
3. create the EKS cluster
4. create the managed node group
5. connect to the cluster with `aws eks update-kubeconfig`
6. deploy workloads with Kubernetes manifests

This order matters because each layer depends on the one before it.

## Architecture

```text
Terraform
   |
   v
AWS VPC
   |
   +--> Public Subnet A
   |
   +--> Public Subnet B
   |
   +--> Internet Gateway
   |
   +--> Route Table
   |
   v
EKS Cluster Control Plane
   |
   v
Managed Node Group
   |
   v
EC2 Worker Nodes
   |
   v
Kubernetes Pods and Services
```

## How EKS Is Provisioned

### 1. AWS provider configuration

Terraform starts by selecting the AWS region in [terraform/main.tf](/Users/vigneshwarik/Desktop/Project3/terraform/main.tf:15).

The region comes from `var.aws_region`, which keeps the project configurable without hardcoding every resource separately.

### 2. VPC and subnet layer

The network is defined in [terraform/vpc.tf](/Users/vigneshwarik/Desktop/Project3/terraform/vpc.tf).

This project provisions:

- 1 VPC
- 2 public subnets
- 1 internet gateway
- 1 public route table
- route table associations for both subnets

Why this matters for EKS:

- EKS requires subnet placement across at least two availability zones
- worker nodes need network access to pull images and join the cluster
- the Kubernetes LoadBalancer service needs subnet tagging so AWS can place the load balancer correctly

Two specific subnet tags are important in this design:

- `"kubernetes.io/cluster/<cluster-name>" = "shared"`
- `"kubernetes.io/role/elb" = "1"`

Those tags allow AWS and Kubernetes integrations to recognize the subnets as valid for cluster and load balancer use.

### 3. IAM role for the EKS control plane

The control plane role is created in [terraform/main.tf](/Users/vigneshwarik/Desktop/Project3/terraform/main.tf:22).

This role is assumed by the `eks.amazonaws.com` service and is attached to `AmazonEKSClusterPolicy`.

Its purpose is to let AWS manage the Kubernetes control plane on your behalf.

Without this role, the EKS cluster resource cannot be created.

### 4. IAM role for worker nodes

The worker node role is created in [terraform/main.tf](/Users/vigneshwarik/Desktop/Project3/terraform/main.tf:47).

It is assumed by EC2 and gets these AWS-managed policies:

- `AmazonEKSWorkerNodePolicy`
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

These policies allow the nodes to:

- join the EKS cluster
- use the AWS VPC CNI networking plugin
- pull container images from registries compatible with that policy set

The node group depends on these attachments, which prevents Terraform from trying to launch nodes before the permissions exist.

### 5. EKS cluster resource

The cluster itself is defined in [terraform/main.tf](/Users/vigneshwarik/Desktop/Project3/terraform/main.tf:80).

Key configuration choices:

- `name = var.cluster_name`
- `version = var.kubernetes_version`
- `role_arn = aws_iam_role.eks_cluster_role.arn`
- both subnets are passed into `vpc_config`
- `endpoint_public_access = true`

What that means:

- the cluster name is stable and reused by the app pipeline
- Kubernetes version is explicitly pinned
- the control plane is attached to the correct IAM role
- the cluster spans both configured subnets
- `kubectl` can reach the API server from GitHub Actions and a local machine

This project uses a public cluster endpoint because it keeps the learning and deployment flow simpler. A more locked-down production setup would often use private endpoints, VPN access, or tighter CIDR restrictions.

### 6. Managed node group resource

The worker nodes are created with `aws_eks_node_group` in [terraform/main.tf](/Users/vigneshwarik/Desktop/Project3/terraform/main.tf:109).

This is a managed node group, which means AWS handles much of the operational lifecycle for the EC2 worker nodes.

Key configuration choices:

- `cluster_name` points at the EKS cluster
- `node_role_arn` points at the EC2 worker IAM role
- `ami_type = var.node_ami_type`
- both public subnets are used
- `instance_types = [var.node_instance_type]`
- scaling uses `desired_size`, `min_size`, and `max_size`

Why these matter:

- explicit AMI selection avoids AWS choosing an incompatible default
- subnet placement spreads workers across both AZs
- instance type stays configurable from variables
- scaling config defines the initial cluster capacity and the allowed size range

This project currently defaults the worker instance type through [terraform/variables.tf](/Users/vigneshwarik/Desktop/Project3/terraform/variables.tf:29) to a Free Tier eligible choice to avoid node launch failures in constrained accounts.

### 7. Terraform dependency handling

EKS provisioning is sensitive to ordering, so this project uses explicit `depends_on` where it matters.

Examples:

- the cluster waits for the cluster IAM policy attachment
- the node group waits for the worker IAM policy attachments

That keeps Terraform from attempting resource creation before AWS permissions are ready.

## How EKS Is Configured For Access

After the cluster exists, access is configured with the kubeconfig command exposed by Terraform outputs in [terraform/outputs.tf](/Users/vigneshwarik/Desktop/Project3/terraform/outputs.tf:20).

The command produced is:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

This updates the local kubeconfig so `kubectl` can authenticate to the EKS API server.

The same cluster name and region are also what the deployment workflow uses when it configures access during CI.

## How Workloads Reach The Internet

This project uses:

- public subnets for worker placement
- public endpoint access for the EKS API
- a Kubernetes `LoadBalancer` service for the app

That means:

- worker nodes can reach the internet directly
- GitHub Actions can reach the Kubernetes API
- AWS provisions a public load balancer for the app service

This is a straightforward architecture for learning and demonstration projects because it removes private networking complexity.

## What Connects EKS To Kubernetes Resources

Terraform only provisions the cluster and nodes.

The actual app runtime is added later by Kubernetes manifests:

- [k8s/deployment.yaml](/Users/vigneshwarik/Desktop/Project3/k8s/deployment.yaml:1) defines the pods
- [k8s/service.yaml](/Users/vigneshwarik/Desktop/Project3/k8s/service.yaml:1) exposes them

So the full model is:

- Terraform creates the platform
- GitHub Actions connects to the cluster
- `kubectl apply` installs the workload

## Practical Design Notes

- Managed node groups are simpler than self-managed nodes for this type of project.
- Public subnets reduce setup complexity, though private subnets are more common in hardened production environments.
- Explicit IAM attachments and explicit subnet tags make EKS provisioning more predictable.
- Pinning Kubernetes version and AMI type makes upgrades more intentional.

## If You Build A Similar Project

The key EKS-specific decisions to make early are:

1. public or private cluster endpoint
2. public or private worker subnets
3. managed or self-managed node groups
4. instance type and scaling range
5. how CI will authenticate to AWS and to the cluster

Those decisions shape nearly all of the Terraform and deployment workflow that follows.
