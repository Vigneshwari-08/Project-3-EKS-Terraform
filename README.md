# 🚀 DevOps Project 3 — EKS + Terraform + Split CI/CD Pipelines

---

## 📁 Structure

```
DevOps-app_Project3/
├── .github/workflows/
│   ├── infra.yml        ← Terraform pipeline (manual / infra changes only)
│   └── app.yml          ← App pipeline (every code push)
├── terraform/
│   ├── main.tf          ← EKS cluster + node group + IAM roles
│   ├── vpc.tf           ← VPC, subnets, internet gateway, routing
│   ├── variables.tf     ← All config values
│   └── outputs.tf       ← Cluster name, endpoint, kubeconfig command
├── k8s/
│   ├── deployment.yaml  ← 2 replicas, rolling update, health checks
│   └── service.yaml     ← LoadBalancer → AWS ELB → public URL
└── README.md
```

---

## ⚡ Key difference from Project 2

| | Project 2 | Project 3 |
|---|---|---|
| Kubernetes | k3s on single EC2 | AWS EKS (managed, multi-AZ) |
| Infra pipeline | Every git push | Manual or terraform/ changes only |
| App pipeline | Mixed with infra | Separate — no Terraform involved |
| Service type | NodePort | LoadBalancer (real AWS ELB) |
| Health checks | None | livenessProbe + readinessProbe |
| Image tagging | latest only | latest + git SHA (rollback-ready) |

---

## 🛠️ One-time setup

### 1. GitHub Secrets needed

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | From AWS IAM |
| `AWS_SECRET_ACCESS_KEY` | From AWS IAM |
| `TF_STATE_BUCKET` | S3 bucket name for Terraform remote state |
| `TF_LOCK_TABLE` | DynamoDB table name for Terraform state locking |
| `DOCKER_USERNAME` | DockerHub username |
| `DOCKER_PASSWORD` | DockerHub password/token |

### 2. Create Terraform remote state storage
Create these once in AWS before running the infra workflow:

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

Then save these names in GitHub repository secrets:
- `TF_STATE_BUCKET=project3-terraform-state-REPLACE_ME`
- `TF_LOCK_TABLE=project3-terraform-locks`

### 3. Update the Docker image name
In `k8s/deployment.yaml` change:
```yaml
image: vigneshwari08/devops-app:latest
```
to your DockerHub username.

---

## 🚀 How to run

### Step 1 — Provision the EKS cluster (run once)
```
GitHub → Actions tab → "Infrastructure Pipeline" → Run workflow → apply
```
This takes ~12 minutes. EKS clusters are slow to create — this is normal.
Terraform state is stored remotely in S3, so future apply/destroy runs use the same state.

### Step 2 — Connect kubectl locally (optional, for verification)
```bash
aws eks update-kubeconfig --region us-east-1 --name devops-project3
kubectl get nodes   # Should show 2 nodes in Ready state
```

### Step 3 — Deploy the app (happens automatically on every push)
```bash
git push origin main
# app.yml triggers automatically
# builds image → deploys to EKS → rollout completes
```

### Step 4 — Get the app URL
```bash
kubectl get service devops-app-service
# Look at EXTERNAL-IP column — that's your public AWS load balancer URL
# Takes ~2 minutes to appear after first deploy
```

---

## 🧹 Teardown (stop AWS charges)
```
GitHub → Actions tab → "Infrastructure Pipeline" → Run workflow → destroy
```
This deletes the EKS cluster, nodes, VPC, and everything Terraform created.

---

## 🔜 Next steps (Step 2 of Project 3)
- Package the app as a **Helm chart** (replace raw kubectl apply)
- Add **Prometheus + Grafana** via kube-prometheus-stack Helm chart
