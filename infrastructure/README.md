# Cloud Infrastructure
This project has a cloud-based backend and web-frontend. The infrastructure is hosted on AWS using Terraform as Infrasture as Code.

## About AWS
- Root Account
- User Accounts
- Access Portal Accounts
- Security Group
- MFA
- Access Key Tokens
-

## About Terraform
Best practice guide: https://buildkite.com/resources/blog/best-practices-for-terraform-ci-cd/
https://www.terraform.io/docs/cloud/index.html

- main.tf, variables.tf, outputs.tf
- Deployment - Run environment/main.tf
- State Files - S3 Buckets

## Local Dev Environment
Terraform commands:
```Bash
# Enable autocomplete
terraform -install-autocomplete
```

## Setup AWS CLI
Install AWS CLI and configure it with your credentials:

```Bash
# Update package list
sudo apt-get update

# Install prerequisites
sudo apt-get install -y unzip curl

# Download and install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version
```

### ```AWS Credential Managment```
Set up AWS IAM identity center for temporary credentials. You need this in order to be able to deploy the infrastructure to AWS.
1. Go to the AWS Management Console and log in to your AWS account.
2. Navigate to the "IAM Identity Center"
3. IAM Identity Center -> Settings - > Enable IAM Identity Center
4. IAM Identity Center -> Users -> Add user
5. Permission sets -> Create permission set
6. AWS accounts -> Select AWS account -> "Assign users or groups" -> Assign permission
7. Open user confirmation-mail and set up password & MFA

**Access Portal**: Setting -> AWS access portall -> Access Key

**Credentials**: Copy "Option 1" and paste it in your terminal:
```Bash
# Unset the AWS_PROFILE environment variable
unset AWS_PROFILE
# Set your credentials as environment variables
# Get em from the AWS access portal
export AWS_ACCESS_KEY_ID="something"
export AWS_SECRET_ACCESS_KEY="something"
export AWS_SESSION_TOKEN="something"
export AWS_REGION="something"  # Hardcode as env var in xdev.sh script
```

Your AWS credentials are now set up. You can verify them by running the following command:
```Bash
aws sts get-caller-identity
```


## Setup Terraform
Install prerequisites and Terraform on Debian Bookworm:
```Bash
# Update package list
sudo apt-get update
# Install prerequisites
sudo apt-get install -y gnupg software-properties-common curl
# Install the lsb-release package
sudo apt-get install -y lsb-release
```

Add the HashiCorp GPG key and repository for Debian Bookworm:
```Bash
# Create the directory for trusted keys
sudo mkdir -p /etc/apt/keyrings
# Download and add the key to a specific keyring file
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
# Add the repository using the specific Debian version
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com bookworm main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
```

Update the package list and install Terraform:
```Bash
# Update package list with the new repository
sudo apt-get update
# Install Terraform
sudo apt-get install terraform
# Verify installation
terraform --version
```

### ```Deploying the infrastructure```
1. Navigate to the `terraform` environment directory:
```Bash
cd infrastructure/deployment/dev
```
2. Initialize Terraform:
```Bash
terraform init
```
3. Validate the Terraform configuration files:
```Bash
terraform validate
```
4. Plan the infrastructure changes:
```Bash
terraform plan
```
5. Apply the changes to create the infrastructure:
```Bash
terraform apply
```

### ```One time setup```
In order to keep track of the Terraform state files, you need to/should set up a remote backend. This is done by creating an S3 bucket and a DynamoDB table for state locking.

This needs to be done only once for the project. The following file sets up the S3 bucket: `infrastructure/terraform/deployment/s3_backend_one_timer/s3_backend_setup.tf`

### ```Retrieve Endpoint URL and API key```
```Bash
aws ssm get-parameter --name "/shared/dev/api-gateway/invoke-url" --region eu-central-1

# First get the key ID
aws apigateway get-api-keys --region eu-central-1

# Then get the actual key value
aws apigateway get-api-key --api-key YOUR_KEY_ID --include-value --region eu-central-1
```



## TF Code Quality - .pre-commit-config-terraform.yaml
TFLint is a Terraform linter for detecting errors in your Terraform code. It helps ensure that your Terraform configurations are clean and follow best practices.
```Bash
# Install tflint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

TFDocs is a tool that generates documentation for Terraform modules. It helps create and maintain documentation for your Terraform code, making it easier to understand and share with others.
```Bash
# Install terraform-docs
curl -sSLo ./terraform-docs.tar.gz https://terraform-docs.io/dl/v0.16.0/terraform-docs-v0.16.0-$(uname)-amd64.tar.gz
tar -xzf terraform-docs.tar.gz
chmod +x terraform-docs
sudo mv terraform-docs /usr/local/bin/
```
