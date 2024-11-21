# Serverless Infra (Blog)

## Running this project
The only dependency needed to start using this project is [Devbox](https://www.jetify.com/devbox) and [Nix](https://nixos.org/download/) (if you install Devbox first it will install Nix for you if you don't have it), all the other tools will be installed by it. Make sure your AWS region was already CDK bootstrapped.

1) Export AWS credentials and region (`AWS_REGION`) environment variables

2) Install dependencies

```sh
devbox shell
```

3) Create S3 for states and DynamoDB table

```sh
cd iac/bootstrap
terraform init
terraform apply
```

Copy the `s3-state-bucket-name` and `dynamodb-lock-table-name` because we will use it to run step 5.

4) Deploy infrastructure

Create `variables.tfvars` in the `iac/src` folder.

```
domain               = "mydomain.com"
frontend_bucket_name = "assets-frontend-serverless-infra-bucket"
```

Modify the `iac/src/versions.tf` file to use the correct `dynamodb_table` and `bucket` created during bootstrap (exported during step 3). Apply the infrastructure code.

```sh
cd ../src/
terraform init
terraform apply --var-file=variables.tfvars
```

It's **expected** for this run to fail.

5) Build and deploy backend image

```sh
cd ../../backend/
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com
docker build -t backend-api .
docker tag backend-api:latest $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/backend-api:latest
docker push $AWS_ACCOUNT.dkr.ecr.$AWS_REGION.amazonaws.com/backend-api:latest
```

6) Push frontend assets to S3 bucket

```sh
cd ../iac/src/
BUCKET=$(terraform output -raw frontend_bucket)
aws s3 sync ../../frontend s3://$BUCKET
```

7) Apply Infrastructure again

```sh
terraform apply --var-file=variables.tfvars
```

All done!