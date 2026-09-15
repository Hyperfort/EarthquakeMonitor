# Earthquake Monitor

Service for querying earthquakes stored in MySQL/RDS.

## Requirements

Install and configure these tools:

- Python 3.10 or newer.
- `uv`.
- Terraform 1.5 or newer.
- Docker Desktop.
- AWS CLI with configured credentials.
- An AWS account with permissions for ECR, ECS, Lambda, RDS, VPC, IAM, ALB, EventBridge, and CloudWatch.

Configure AWS and verify the region:

```sh
aws configure
aws sts get-caller-identity
export AWS_REGION=us-east-2
```

## Structure

```text
app/
  api.py              # FastAPI API
  lambda_ingestion.py # Lambda handler
  Dockerfile          # ECS image
  build_lambda.sh     # Lambda ZIP build script
  pyproject.toml
  uv.lock
infra/
  environments/dev/   # Development environment configuration
  modules/            # Reusable Terraform modules
docs/
  architecture-and-sre.md # Architecture and SRE documentation
observability/
  main.tf                 # Datadog Synthetic API tests
  variables.tf            # Datadog and API test configuration
  terraform.tfvars.example
```

## Local Setup

From the project root:

```sh
cd app
python -m venv --prompt Rhyperior .venv
source .venv/bin/activate
python -m pip install --upgrade pip
uv sync
```

If you prefer to create the environment with `uv` while preserving the prompt name, you can also do:

```sh
cd app
uv venv --python 3.12 --prompt Rhyperior .venv
source .venv/bin/activate
uv sync
```

## Run the API Locally

The API requires an accessible MySQL database and these variables:

```sh
export DB_HOST="localhost"
export DB_USERNAME="admin"
export DB_PASSWORD="your-password"
export DB_NAME="rhyperior"
```

Start FastAPI:

```sh
cd app
uv run uvicorn api:app --host 0.0.0.0 --port 8080
```

Available endpoints:

```sh
curl http://localhost:8080/health
curl http://localhost:8080/quakes/latest
curl http://localhost:8080/quakes/top?days=30&limit=5
curl http://localhost:8080/quakes/weekly-average
```

## Local Validation

```sh
app/.venv/bin/python -m compileall -q app
terraform fmt -check -recursive infra
terraform -chdir=infra/environments/dev validate
```

## Build the Lambda Package

The package includes `lambda_ingestion.py`, `pymysql`, `requests`, and their dependencies:

```sh
sh app/build_lambda.sh
unzip -l app/ingestion.zip | grep -E 'lambda_ingestion.py|pymysql|requests'
```

Terraform expects this file at `app/ingestion.zip`. Do not commit the artifact or the temporary build directory.

## Build the ECS Image

ECS/Fargate uses the `x86_64` architecture by default. On Apple Silicon, explicitly build for Linux AMD64:

```sh
docker build --platform linux/amd64 \
  -t rhyperior:latest app
```

Test the image locally:

```sh
docker run --rm -d \
  --name rhyperior \
  -p 8080:8080 \
  -e DB_HOST="$DB_HOST" \
  -e DB_USERNAME="$DB_USERNAME" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e DB_NAME="$DB_NAME" \
  rhyperior:latest

curl http://localhost:8080/health
docker stop rhyperior
```

## Publish the Image to ECR

Set the repository name and get your AWS Account ID:

```sh
export AWS_REGION=us-east-2
export ECR_REPOSITORY=rhyperior
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account --output text)
export ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"
```

Create the repository if it does not exist yet:

```sh
aws ecr describe-repositories \
  --repository-names "$ECR_REPOSITORY" \
  --region "$AWS_REGION" >/dev/null 2>&1 || \
aws ecr create-repository \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION"
```

Authenticate Docker, tag the image, and push it:

```sh
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker tag rhyperior:latest "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"
```

Verify that the image was uploaded to ECR:

```sh
aws ecr describe-images \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION"
```

## Terraform Variables

Create a local `infra/environments/dev/terraform.tfvars` file:

```hcl
db_password = "change-this-password"
api_image   = "123456789012.dkr.ecr.us-east-2.amazonaws.com/rhyperior:latest"
```

Replace `123456789012` with your AWS Account ID. Do not commit this file because it contains the RDS password.

You can also use environment variables:

```sh
export TF_VAR_db_password='change-this-password'
export TF_VAR_api_image="$ECR_URI:latest"
```

## Switch AWS Account or Profile

If you need to run this project against a different AWS account, switch the active profile before Terraform or Docker commands:

```sh
aws configure --profile another-account
export AWS_PROFILE=another-account
export AWS_REGION=us-east-2
aws sts get-caller-identity
```

If you are using environment variables instead of a profile:

```sh
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."  # only if required
export AWS_REGION=us-east-2
aws sts get-caller-identity
```

To switch back to the default profile:

```sh
export AWS_PROFILE=default
export AWS_REGION=us-east-2
aws sts get-caller-identity
```

## Deploy the Infrastructure

From the project root:

```sh
aws configure
export AWS_PROFILE=default
export AWS_REGION=us-east-2

sh app/build_lambda.sh
cd infra/environments/dev
terraform init
terraform fmt -check -recursive ../..
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

To use environment variables instead of `terraform.tfvars`:

```sh
terraform plan
terraform apply
```

After deployment, Terraform will display the available outputs. The ALB exposes the API over HTTP on port 80 and forwards traffic to the ECS service on port 8080.

## Redeploy Application Changes

From the project root, rebuild the Lambda ZIP whenever `app/lambda_ingestion.py` changes. Rebuild and publish the ECS image whenever `app/api.py` changes:

```sh
export AWS_REGION=us-east-2
export ECR_REPOSITORY=rhyperior
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY"

sh app/build_lambda.sh

docker build --platform linux/amd64 -t rhyperior:latest app
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin \
  "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
docker tag rhyperior:latest "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"
```

Apply the Lambda package and infrastructure changes, then force ECS to pull the refreshed `latest` image:

```sh
cd infra/environments/dev
terraform apply -var-file=terraform.tfvars
aws ecs update-service \
  --cluster rhyperior-monitor-cluster \
  --service rhyperior-monitor-service \
  --force-new-deployment \
  --region "$AWS_REGION"
aws ecs wait services-stable \
  --cluster rhyperior-monitor-cluster \
  --services rhyperior-monitor-service \
  --region "$AWS_REGION"
```

When using the mutable `:latest` tag, the forced ECS deployment is required after pushing a changed image. For production, prefer immutable image tags or digests.

## Test Lambda Ingestion

EventBridge runs ingestion every five minutes, but invoke the function manually when testing a deployment:

```sh
aws lambda invoke \
  --function-name rhyperior-monitor-ingestion \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  /tmp/lambda-out.json
cat /tmp/lambda-out.json
```

Inspect recent Lambda logs if the invocation fails or ingests zero records:

```sh
aws logs tail /aws/lambda/rhyperior-monitor-ingestion \
  --since 15m \
  --follow
```

## Verify the Deployment

Wait a minute or two for the ECS service and ALB health checks to become healthy, then inspect the outputs:

```sh
cd infra/environments/dev
terraform output
terraform output -raw api_url
terraform output -raw alb_dns_name
```

Test the live endpoints:

```sh
curl "$(terraform output -raw api_url)/health"
curl "$(terraform output -raw api_url)/quakes/latest"
curl "$(terraform output -raw api_url)/quakes/top?days=30&limit=5"
```

`/quakes/latest` returns recent records from the last seven days. An empty array means no records are currently in that time window; confirm ingestion with the Lambda invocation and logs above.

## Destroy the Environment

Use this operation carefully: it deletes the infrastructure and database.

```sh
cd infra/environments/dev
terraform destroy -var-file=terraform.tfvars
```

## Important Notes

- Lambda uses the `lambda_ingestion.lambda_handler` handler.
- EventBridge invokes Lambda every five minutes.
- Private subnets use NAT Gateways so Lambda can query USGS and ECS can pull images and send logs.
- The API uses `/health` as the container and ALB health check; it does not verify the RDS connection.
- Credentials are currently passed through Terraform variables and stored in Terraform state. For production, use AWS Secrets Manager or SSM Parameter Store.
- Do not run `terraform apply` without providing `db_password` and `api_image`.
