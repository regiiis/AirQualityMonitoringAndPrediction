# Cloud Infrastructure
This project has a cloud-based backend and web-frontend. The infrastructure is hosted on AWS using Terraform as Infrasture as Code.

## Dev Environment
Terraform commands:
```Bash
# Enaböle autocomplete
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

Setup AWS account credentials:
```Bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region name (e.g., us-west-2)
# - Default output format (json)
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

## Setup TF pre-commits in .pre-commit-config-terraform.yaml
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
