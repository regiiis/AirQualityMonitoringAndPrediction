# Indoor Air Quality Monitoring And Prediction
A indoor air quality monitoring- and prediction project for learning purposes.

## Motivation
This is an end-to-end air quality monitoring and prediction project. In order to do so, a sensor module is installed in an appartment room, which collects and periodically sends measurement data to a server.

The goal of this project is to learn and apply MLOps best practices to an air quality monitoring use-case. The following topics are aimed to be covered:

| MLOps Component | Key Aspects |
|-|-|
| **Dev & Ops** | • Version Control & CI/CD<br>• Code Quality & Testing<br>• Infrastructure Automation<br>• Container Orchestration<br>• Security & Monitoring |
| **Data Pipeline** | • Ingestion & Validation<br>• Feature Engineering<br>• Data Versioning<br>• Feature Store Integration |
| **ML Lifecycle** | • Training & Experimentation<br>• Model Registry & Versioning<br>• Deployment & Serving<br>• Performance Monitoring<br>

### Technology Stack

| Component | Tools & Technologies |
|-|-|
| **Development** | • Git - Version Control<br>• GitHub Actions - CI/CD<br>• pre-commit - Code Quality |
| **Data** | • InfluxDB - Time Series DB<br>• DVC - Data Version Control<br>• Feast - Feature Store |
| **ML & Deploy** | • scikit-learn, MLflow - Training<br>• FastAPI, Docker - Serving<br>• Kubernetes - Orchestration |
| **Infrastructure** | • AWS - Cloud Platform<br>• Terraform - IaC<br>• Prometheus/Grafana - Monitoring |

## Solution Design

### Vision Statement
Create an indoor air quality monitoring system that helps users maintain optimal CO2 levels through real-time monitoring, predictive analytics and event detection.

### 1. Project Goals
- Monitor and predict indoor air quality (CO2, humidity, temperature)
- Provide real-time insights through visualizations
- Enable predictive maintenance and alerts

#### Core Features
1. **Real-Time Monitoring**
   - Live CO2, humidity and temperature measurements
   - Interactive dashboards
   - Alert system for detectd events

2. **Predictive Analytics**
   - 24-hour forecasts for CO2, humidity and temperature
   - Trend analysis and pattern detection
   - Multiple prediction models comparison

3. **Data Management**
   - Historical data storage and retrieval
   - Data quality monitoring
   - Automated data collection



### 2. Requirements

| Requirements Type | Description | Specifications |
|-|-|-|
| **Functional** | Real-time Monitoring | • Sensor data collection every 5min<br>• Live dashboard updates<br>• Historical data view |
| | Predictions | • 24h forecasting window<br>• Multiple model support<br>• Accuracy metrics display |
| | Alerts | • Threshold configuration<br>• Email/SMS notifications<br>• Alert history |
| **Non-Functional** | Performance | • Data latency < 1s<br>• API response < 500ms<br>• 95% uptime |
| | Scalability | • Multi-sensor support<br>• Concurrent users<br>• Data retention policy |
| | Security | • Encrypted transmission<br>• Access control<br>• Secure API endpoints |


### 3. System Components
| Component | Description | Key Features |
|-|-|-|
| **Sensor Module** | Data collection unit | • CO2/humidity sensors<br>• Batch API<br>• Secure transmission <br>• 72h backend-independency |
| **Backend Server** | Computation Backend | • Handles communication to sensor module<br>• Orchestrates **Data Pipeline**, **ML System** and **Web Interface**<br>|
| **Data Pipeline** | Data processing system | • Real-time ingestion<br>• Data validation<br>• Feature engineering |
| **ML System** | Prediction engine | • Model training<br>• Automated retraining|
| **Web Interface** | User dashboard | • Live monitoring<br>• Predictions view<br>• Alert management |



### Development Roadmap


<br>
<br>
<br>

## Sensor Module

## System Architecture


## Logic Directory Structure
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

## Project Documentation
The project is documented by means of a wiki and README's.

### README
Every folder should have a README providing an overview and describing specific aspect of the substructure.

### Wiki - Sphinx
Sphix is used to automatically generate a docstring documentation as well as dedicated pages in marksdown.

## Version Control
A guideline for version control in this project
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
