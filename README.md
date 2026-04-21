# DevOps Project 3 - EKS + Terraform + App CI/CD

This repository now contains both:

- the infrastructure for AWS EKS
- the application files that are built into the Docker image and deployed to EKS

The app pipeline builds the image from this repo, pushes it to Docker Hub, and deploys it to the EKS cluster created by Terraform.

For a step-by-step builder guide with architecture and implementation flow, see [BUILD_REFERENCE.md](/Users/vigneshwarik/Desktop/Project3/BUILD_REFERENCE.md).

## Project Structure

```text
Project3/
├── .github/workflows/
│   ├── infra.yml        # Terraform pipeline for EKS infrastructure
│   └── app.yml          # App build + deploy pipeline
├── app/
│   ├── index.html       # Static app entry page
│   ├── script.js        # Frontend behavior
│   └── style.css        # App styling
├── terraform/
│   ├── backend.tf       # Remote state backend config
│   ├── main.tf          # EKS cluster, node group, IAM roles
│   ├── outputs.tf       # Useful Terraform outputs
│   ├── variables.tf     # Configurable values
│   └── vpc.tf           # VPC, subnets, internet gateway, routing
├── k8s/
│   ├── deployment.yaml  # Kubernetes deployment
│   └── service.yaml     # Kubernetes LoadBalancer service
├── Dockerfile           # Builds the Nginx-based app image
├── nginx.conf           # Nginx config used inside the container
└── README.md
```

## How This Repo Works

### Infrastructure pipeline

`infra.yml` is responsible for:

- creating the VPC and networking
- creating the EKS cluster
- creating the managed node group
- storing Terraform state in S3 with DynamoDB locking

Run this workflow manually when you want to apply or destroy infrastructure.

### Application pipeline

`app.yml` is responsible for:

- building the Docker image from this repository
- pushing the image to Docker Hub
- connecting to the existing EKS cluster
- applying the Kubernetes manifests in `k8s/`
- updating the deployment image to the latest commit SHA

This means the app source files, `Dockerfile`, and `nginx.conf` must live in this repo for the current workflow to work correctly.

## Key Difference From Project 2

| Area | Project 2 | Project 3 |
|---|---|---|
| Kubernetes | k3s on one EC2 | AWS EKS managed cluster |
| Infra | Single VM style setup | Terraform-managed AWS infra |
| App deployment | Simpler local/server deployment | GitHub Actions to EKS |
| Service exposure | NodePort/basic access | AWS LoadBalancer |
| Image rollout | Basic image update | `latest` plus commit SHA |

## One-Time Setup

### 1. GitHub secrets

Add these repository secrets:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `TF_STATE_BUCKET` | S3 bucket for Terraform state |
| `TF_LOCK_TABLE` | DynamoDB table for Terraform locking |
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password or access token |

### 2. Create Terraform remote state resources

Create these once before running the infrastructure workflow:

```bash
aws s3api create-bucket \
  --bucket project3-terraform-state-REPLACE_ME \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket project3-terraform-state-REPLACE_ME \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name project3-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Then save those names in GitHub secrets:

- `TF_STATE_BUCKET=project3-terraform-state-REPLACE_ME`
- `TF_LOCK_TABLE=project3-terraform-locks`

### 3. Update the Docker image reference

In [k8s/deployment.yaml](/Users/vigneshwarik/Desktop/Project3/k8s/deployment.yaml:36), set the image to your Docker Hub username if needed:

```yaml
image: your-dockerhub-username/devops-app:latest
```

The GitHub Actions deploy step also updates the image to:

```text
<DOCKER_USERNAME>/devops-app:<git-sha>
```

So the Kubernetes image name and your Docker Hub secrets should match.

## Run Order

### Step 1. Provision infrastructure

From GitHub Actions:

```text
Actions -> Infrastructure Pipeline -> Run workflow -> apply
```

This creates the EKS cluster and node group. EKS creation usually takes several minutes.

Note: the node group default is set to `t3.micro` to stay Free Tier eligible for EC2, but EKS control plane charges still apply.

### Step 2. Verify cluster access locally

```bash
aws eks update-kubeconfig --region us-east-1 --name devops-project3
kubectl get nodes
```

You should see the worker nodes in `Ready` state.

### Step 3. Deploy the application

Push to `main`:

```bash
git push origin main
```

The app pipeline will:

- build the image from `Dockerfile`
- copy the contents of `app/` into the container
- use `nginx.conf` inside the image
- push the image to Docker Hub
- deploy the manifests in `k8s/`

### Step 4. Get the public URL

```bash
kubectl get service devops-app-service
```

Check the `EXTERNAL-IP` or hostname shown by the AWS LoadBalancer.

## Local File Roles

- `Dockerfile` uses `nginx:latest`
- `app/` is copied into `/usr/share/nginx/html`
- `nginx.conf` replaces the default Nginx configuration
- `k8s/deployment.yaml` runs 2 replicas of the container
- `k8s/service.yaml` exposes the app using a LoadBalancer

## Teardown

To stop AWS resources:

```text
Actions -> Infrastructure Pipeline -> Run workflow -> destroy
```

This removes the EKS cluster, node group, VPC, and other Terraform-managed AWS resources.

## Important Notes

- This repo is now a combined infra + app repo.
- The application pipeline assumes the app files are inside this same repository.
- If you later move the app back to another repo, `app.yml` will need to be changed to check out that repo or the pipeline should live there instead.

## Next Steps

- Package the Kubernetes app deployment as a Helm chart.
- Add monitoring with Prometheus and Grafana.
