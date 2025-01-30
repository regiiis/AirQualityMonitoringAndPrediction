# CO2 Monitoring And Prediction
A CO2 room-concentration monitoring- and prediction project.

## Motivation
This is an end-to-end air humidity and CO2-concentration monitoring and prediction project. In order to do so, a sensor module is installed in an appartment room, which collects and periodically sends measurement data to a server.

The goal of this project is to learn and apply MLOps best practices to a CO2 monitoring use-case. The following topics will be covered:

| MLOps Component | Key Aspects |
|----------------|-------------|
| **Dev & Ops** | • Version Control & CI/CD<br>• Code Quality & Testing<br>• Infrastructure Automation<br>• Container Orchestration<br>• Security & Monitoring |
| **Data Pipeline** | • Ingestion & Validation<br>• Feature Engineering<br>• Data Versioning<br>• Feature Store Integration |
| **ML Lifecycle** | • Training & Experimentation<br>• Model Registry & Versioning<br>• Deployment & Serving<br>• Performance Monitoring<br>

### Technology Stack

| Component | Tools & Technologies |
|-----------|-------------------|
| **Development** | • Git - Version Control<br>• GitHub Actions - CI/CD<br>• pre-commit - Code Quality |
| **Data** | • InfluxDB - Time Series DB<br>• DVC - Data Version Control<br>• Feast - Feature Store |
| **ML & Deploy** | • scikit-learn, MLflow - Training<br>• FastAPI, Docker - Serving<br>• Kubernetes - Orchestration |
| **Infrastructure** | • AWS - Cloud Platform<br>• Terraform - IaC<br>• Prometheus/Grafana - Monitoring |

## Features
- Live sensor data monitoring
- CO2 and humidity prediction
- Model performance dashboard
- Automated retraining pipeline
<br>
<br>
<br>

## Sensor Module

### Logic Directory Structure
## System Architecture

```plaintext
app
|
├── 
```


### Infrastructure System Diagram
Following the Cloud ressource system diagram  - [Generate System Diagram](#generate-system-diagram):

<br>
<p align="center">
  <img src="diagram.png" width="600" alt="System Diagram">
</p>
<br>

## Setup for Development

### Python Virtual Environment
```bash
# Create new virtual environment
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate
```


### Daily Command for Local Dev
```bash
# Activate Python virtual environment
source .venv/bin/activate

# Install Python packages
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Install pre-Commits
pre-commit install
```

## Version Control

### Link GitHub to WSL

```bash
# 1. Update package manager and install git
sudo apt-get update
sudo apt-get install git

# 2. Generate SSH key
# Save to default location when prompted
mkdir -p ~/.ssh
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# 4. Start the SSH agent and add your new key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa

# 4. Display and copy your public key
cat ~/.ssh/id_rsa.pub
```
5. Add to GitHub:

- Go to GitHub → Settings → SSH and GPG keys
- Click "New SSH key"
- Paste your key and save
```bash
# 6. Configure Git globally
git config --global user.name "Any Name"
git config --global user.email "your.email@example.com"

# 7. Test connection
ssh -T git@github.com
```
```bash
# 8. Set remote URL
git remote set-url origin 
```

### Commit naming rules


| Type | Purpose | Examples |
|------|---------|----------|
| `feat` | Change source code | New features, code changes |
| `ci` | CI configuration | CI Pipeline, GitHub Actions updates |
| `test` | Test-related changes | Adding/updating test cases |
| `perf` | Performance improvements | Optimization |
| `build` | Build system or dependency changes | Build scripts, dependency updates |
| `chore` | Routine maintenance tasks | Version updates, file renaming |
| `refactor` | Non-feature code changes | Code reorganization, readability |
| `style` | Code formatting changes | Whitespace, semicolons |
| `docs` | Documentation updates | README changes, code comments |
