# Memos on AWS ECS Fargate

A self-hosted deployment of [Memos](https://github.com/usememos/memos) on AWS ECS Fargate, provisioned with Terraform and deployed via GitHub Actions CI/CD.

🌐 **Live URL:** https://tm.myegh.com

---

## Architecture
```mermaid
graph TD
    User["👤 User"] -->|HTTPS| Route53["Route 53\ntm.myegh.com"]
    Route53 --> ALB["Application Load Balancer\nPort 80 → 443 redirect\nACM TLS Certificate"]
    ALB -->|Port 8081| ECS["ECS Fargate\nmemos-cluster\nmemos-service"]
    ECS --> ECR["ECR\nDocker Image"]
    ECS --> CW["CloudWatch Logs\n/ecs/memos"]
    
    GHA["GitHub Actions\nbuild.yml + deploy.yml"] -->|Push image| ECR
    GHA -->|terraform apply| Infra["Terraform\nS3 Backend + DynamoDB Lock"]
    
    subgraph VPC ["VPC 10.0.0.0/16"]
        subgraph Public ["Public Subnets (eu-west-1a/1b)"]
            ALB
        end
        subgraph Private ["Private Subnets (eu-west-1a/1b)"]
            ECS
        end
    end
```


## Docker Image Optimisation

I compared single-stage and multi-stage builds of the same
application source, targeting linux/amd64 and using the same
Go compilation flags.

| Build type | Disk usage | Content size |
|---|---:|---:|
| Single-stage | 2.79 GB | 633 MB |
| Multi-stage | 75.8 MB | 19.7 MB |

The multi-stage image uses approximately 97.3% less disk space.

The single-stage image retains the compilers, source code and
build dependencies. The multi-stage build separates frontend
compilation, backend compilation and runtime packaging. Its
final image contains the compiled application, embedded frontend
assets and runtime dependencies.

Measurements were taken using `docker images memos`.
Percentages are approximate because the displayed sizes are rounded.
Node.js is supplied by different base distributions in the two builds.

To reproduce:

docker build --platform linux/amd64 -t memos:multi-stage .
docker build --platform linux/amd64 -f Dockerfile.single-stage -t memos:single-stage .
docker images memos

## Infrastructure Overview

| Component | Details |
|-----------|---------|
| Cloud | AWS eu-west-1 |
| Compute | ECS Fargate (256 CPU, 512MB RAM) |
| Container Registry | Amazon ECR |
| Load Balancer | Application Load Balancer |
| TLS | AWS Certificate Manager |
| DNS | Route 53 |
| State Backend | S3 + DynamoDB locking |
| IaC | Terraform (modular) |
| CI/CD | GitHub Actions with OIDC |

### Terraform Modules
```
infra/
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
├── terraform.tfvars
└── modules/
    ├── vpc/        # VPC, subnets, IGW, NAT, route tables
    ├── ecs/        # Cluster, task definition, service
    ├── alb/        # ALB, target group, listeners
    ├── ecr/        # Container registry
    ├── acm/        # TLS certificate
    ├── iam/        # Execution and task roles
    └── security/   # Security groups
```

---

## CI/CD Pipeline

Two separate GitHub Actions workflows:

### `build.yml` — Build and Push
- Triggers on push to `main` or manual `workflow_dispatch`
- Authenticates to AWS via **OIDC** (no static keys)
- Builds Docker image and tags with Git SHA
- Pushes to ECR

### `deploy.yml` — Deploy and Verify
- Triggers automatically when `build.yml` completes
- Runs `terraform fmt`, `validate`, `plan`, `apply`
- Waits 60s then hits `/healthz` — fails pipeline if unhealthy

### Required GitHub Secret
| Name | Description |
|------|-------------|
| `AWS_ROLE_ARN` | ARN of the IAM role with OIDC trust policy |

---

## Screenshots

### VPC
![VPC](screenshots/VPC.png)

### Public Subnets
![Subnets](screenshots/2%20Public%20subnets.png)

### Security Groups
![Security Groups](screenshots/2%20SGs.png)

### Certificate Issued
![ACM Certificate](screenshots/certificate%20issued.png)

### DNS Resolution
![DNS](screenshots/DNS%20Resolution.png)

### Pushed to ECR
![ECR](screenshots/Pushed%20to%20ECR.png)

### Load Balancer Working
![ALB](screenshots/LB%20Working.png)

### Docker Image Running
![Docker](screenshots/Docker%20image%20running.png)

### Service Healthy in Cluster
![ECS](screenshots/Service%20Healthy%20in%20Cluster.png)

### Website Live with HTTPS
![Live](screenshots/Website%20succesfully%20working%20with%20cert.png)

---

## How to Reproduce

### Prerequisites
- AWS CLI configured
- Terraform >= 1.6.0
- Docker
- A registered domain in Route 53

### 1. Clone the repo
```bash
git clone https://github.com/EnamulRahman/ECS-Project.git
cd ECS-Project
```

### 2. Create S3 backend
```bash
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### 3. Update variables
Edit `infra/terraform.tfvars` with your domain, region, and bucket name.

### 4. Deploy infrastructure
```bash
cd infra
terraform init
terraform apply
```

### 5. Set up OIDC for GitHub Actions
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list ffffffffffffffffffffffffffffffffffffffff

aws iam create-role \
  --role-name github-actions-role \
  --assume-role-policy-document file://oidc-trust-policy.json

aws iam attach-role-policy \
  --role-name github-actions-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Add `AWS_ROLE_ARN` to GitHub repository secrets.

### 6. Push to main
Any push to `main` will trigger the full build and deploy pipeline.

### 7. Tear down
```bash
cd infra
terraform destroy
```

---

## Key Design Decisions

- **Fargate over EC2** — no server management, scales to zero
- **Private subnets for ECS** — containers not directly internet accessible, traffic only via ALB
- **OIDC over static keys** — no long-lived AWS credentials stored in GitHub
- **Modular Terraform** — each layer isolated and independently manageable
- **Multi-stage Dockerfile** — separate frontend (Node/pnpm) and backend (Go) build stages for smaller final image
