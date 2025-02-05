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
| **Data** | • Data Version Control<br>|
| **ML & Deploy** | • Docker|
| **Infrastructure** | • AWS - Cloud Platform<br>• CDK - IaC<br>|

## Solution Design

### Vision Statement
Create an indoor air quality monitoring system that helps users maintain optimal CO2 levels through real-time monitoring, predictive analytics and event detection.

### 1. Project Goals
- Monitor and predict indoor air quality (CO2, humidity, temperature)
- Provide real-time insights through visualizations
- Enable air quality prediction and alerts

#### Core Features
1. **Real-Time Monitoring**
   - Live CO2, humidity and temperature measurements
   - Interactive dashboards
   - Alert system for detected events

2. **Predictive Analytics**
   - 24-hour forecasts for CO2, humidity and temperature
   - Multiple prediction model:
   - Time Series
   - Polynomial Regression
   - DNN
   - DNN with enriched Data
   - Models comparison & benchmarking

3. **Data Management**
   - Historical data storage and retrieval
   - Data quality monitoring
   - Automated data collection



### 2. Requirements

| Requirements Type | Description | Specifications |
|-|-|-|
| **Functional** | Real-time Monitoring | • Sensor data collection every 30s<br>• Live dashboard updates<br>• Historical data view |
| | Predictions | • 24h forecasting window<br>• Benchmarking|
| | Alerts | • Threshold configuration<br>• Email/SMS notifications<br>• Alert history |
| **Non-Functional** | Performance | • Data latency < 1s<br>• API response < 500ms<br>• 95% uptime |
| | Scalability | • Multi-sensor<br>• Multi-model<br>• Concurrent users|
| | Security | • Encrypted transmission<br>• Access control<br>• Secure API endpoints |


### 3. System Components
| Component | Description | Key Features |
|-|-|-|
| **Sensor Module** | Data collection unit | • CO2/humidity sensors<br>• Batch API<br>• Secure transmission <br>• 72h backend-server independency |
| **Backend Server** | Computation Backend | • Handles communication to sensor module<br>• Orchestrates **Data Pipeline**, **ML System** and **Web Interface**<br>|
| **Data Pipeline** | Data processing system | • Real-time ingestion<br>• Data validation<br>• Feature engineering |
| **ML System** | Prediction engine | • Model training<br>• Automated retraining|
| **Web Interface** | User dashboard | • Live monitoring<br>• Predictions view<br>• Alert management |


<br>

## Project Roadmap
### **MVP**
A web page with CO2 and Humidity TS Dashboard, consisting of the following componenets:
<br>

| Sensor Modul | Backend | Frontend |
|-|-|-|
| • Sensors<br>• PV & Battery<br>• MC<br>• MC Logic | • Data Pipeline <br>• Database <br>• Frontend Host | • Webpage <br>• Login <br>• Dashboard (static)

- The **Sensor Module** is assembled and runned by software that collects and sends data to the backend.<br>
- The **Backend** hosts and serves the frontend. The backend receives and stores data from the sensor module.<br>
- The **Frontend** is a static webpage with login. A dashboard is loaded with the most recent data on the database.

**Data Pipeline**<br>
Logic: Data Collection -> Data Quality Gate -> Data Storage<br>
Infrastructure: API Gateway (Data Collection) -> Lambda Function (Data Quality Gate) -> S3 Bucket (Data Storage: main_db or anomaly_db)

**Frontend**<br>
Logic:

**MC Logic**<br>
Logic: Collects Data -> Sends Data

### 1st Feature Implementation
- Add first model to dashboard

### 2nd Feature Implementation
- Add brightness sensor
- Add V & I meter for PV and battery
- Add battery charge status monitoring
- Add PV Power monitoring
- Add brightness monitoring

### 3rd Feature Implementation
- Add two additional models
- Add model benchmarking
- Build Sensor module chassis

### 4th Feature Implementation
- Add model with meteo data enrichment
- Add battery charging prediction

### 5th Feature Implementation
- Make Dashboard interactive
- Make Dashboard Dynamic (Live)


<br>
## Sensor Module
Inspiration:
<br>
https://www.researchgate.net/figure/Circuit-design-of-the-Solar-Power-Monitoring-and-Data-Logger-System_fig1_371709290

https://link.springer.com/article/10.1007/s42452-020-2997-4

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
Use Linux. If you have windows, use Ubuntu-based WSL.

### Python Virtual Environment
```bash
# Install proper venv lib for linux
sudo apt install python3.12-venv

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
Sphix is used to automatically generate a code docstring documentation as well as dedicated pages in marksdown.

## Version Control
A guideline for version control in this project - Work on main except for larger parallel feature devs or experimentations.
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
# Use SSH URL
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
